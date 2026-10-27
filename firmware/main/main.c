// ABOUTME: Firmware entry point: starts the Lua runtime, then poses as a MoonBoard LED box over BLE.
// ABOUTME: Exposes the Nordic UART Service and prints one "rx ..." line per write on the console.

#include <stdio.h>
#include <string.h>

#include "esp_timer.h"
#include "nvs_flash.h"

#include "host/ble_hs.h"
#include "host/util/util.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#include "lua_runtime.h"
#include "rx_log.h"

// Name of the original Moon LED box.
#define DEVICE_NAME "Moonboard A"

void ble_store_config_init(void);

// Nordic UART Service, 6e40000x-b5a3-f393-e0a9-e50e24dcca9e, little-endian.
#define NUS_UUID(x) \
    BLE_UUID128_INIT(0x9e, 0xca, 0xdc, 0x24, 0x0e, 0xe5, 0xa9, 0xe0, \
                     0x93, 0xf3, 0xa3, 0xb5, (x), 0x00, 0x40, 0x6e)

static const ble_uuid128_t nus_service_uuid = NUS_UUID(0x01);
static const ble_uuid128_t nus_rx_uuid = NUS_UUID(0x02);
static const ble_uuid128_t nus_tx_uuid = NUS_UUID(0x03);

static uint8_t own_addr_type;
static int connection_count = 0;

// Runs the protocol logic; open for the life of the firmware. Lua is not
// thread-safe: only one task may ever use this state.
static lua_State *lua = NULL;

static void advertise(void);

static int nus_access(uint16_t conn_handle, uint16_t attr_handle,
                      struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    if (ctxt->op != BLE_GATT_ACCESS_OP_WRITE_CHR) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    static uint8_t data[RX_LOG_DATA_MAX];
    static char line[RX_LOG_LINE_MAX];
    uint16_t len = 0;
    if (ble_hs_mbuf_to_flat(ctxt->om, data, sizeof data, &len) != 0) {
        printf("rx-error conn=%u reason=too-long\n", conn_handle);
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }

    uint32_t ms = (uint32_t)(esp_timer_get_time() / 1000);
    if (rx_log_format(line, sizeof line, ms, conn_handle, data, len) > 0) {
        printf("%s\n", line);
    }
    return 0;
}

static const struct ble_gatt_svc_def gatt_services[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &nus_service_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &nus_rx_uuid.u,
                .access_cb = nus_access,
                .flags = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_WRITE_NO_RSP,
            },
            {
                // Never used by the app, but some iOS versions refuse to connect without it.
                .uuid = &nus_tx_uuid.u,
                .access_cb = nus_access,
                .flags = BLE_GATT_CHR_F_NOTIFY,
            },
            {0},
        },
    },
    {0},
};

static int gap_event(struct ble_gap_event *event, void *arg)
{
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        printf("connect conn=%u status=%d\n",
               event->connect.conn_handle, event->connect.status);
        if (event->connect.status == 0) {
            connection_count++;
        }
        if (connection_count < CONFIG_BT_NIMBLE_MAX_CONNECTIONS) {
            advertise();
        }
        return 0;

    case BLE_GAP_EVENT_DISCONNECT:
        printf("disconnect conn=%u reason=%d\n",
               event->disconnect.conn.conn_handle, event->disconnect.reason);
        connection_count--;
        advertise();
        return 0;

    case BLE_GAP_EVENT_MTU:
        printf("mtu conn=%u mtu=%u\n", event->mtu.conn_handle, event->mtu.value);
        return 0;

    case BLE_GAP_EVENT_SUBSCRIBE:
        printf("subscribe conn=%u notify=%d\n",
               event->subscribe.conn_handle, event->subscribe.cur_notify);
        return 0;

    case BLE_GAP_EVENT_ENC_CHANGE:
        // Shows whether the app pairs at all, which is not known yet.
        printf("encryption conn=%u status=%d\n",
               event->enc_change.conn_handle, event->enc_change.status);
        return 0;

    case BLE_GAP_EVENT_REPEAT_PAIRING: {
        // The phone lost its bond (e.g. "forget device") but we still have
        // one: drop ours and let it pair again.
        struct ble_gap_conn_desc desc;
        if (ble_gap_conn_find(event->repeat_pairing.conn_handle, &desc) == 0) {
            ble_store_util_delete_peer(&desc.peer_id_addr);
        }
        printf("repeat-pairing conn=%u\n", event->repeat_pairing.conn_handle);
        return BLE_GAP_REPEAT_PAIRING_RETRY;
    }

    case BLE_GAP_EVENT_ADV_COMPLETE:
        advertise();
        return 0;

    default:
        return 0;
    }
}

// Advertising data holds the flags and the service UUID; the name goes in the
// scan response because all three don't fit in 31 bytes.
static void advertise(void)
{
    struct ble_hs_adv_fields fields = {0};
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.uuids128 = &nus_service_uuid;
    fields.num_uuids128 = 1;
    fields.uuids128_is_complete = 1;
    int rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        printf("adv-error step=fields rc=%d\n", rc);
        return;
    }

    struct ble_hs_adv_fields response = {0};
    response.name = (const uint8_t *)DEVICE_NAME;
    response.name_len = strlen(DEVICE_NAME);
    response.name_is_complete = 1;
    rc = ble_gap_adv_rsp_set_fields(&response);
    if (rc != 0) {
        printf("adv-error step=response rc=%d\n", rc);
        return;
    }

    struct ble_gap_adv_params params = {0};
    params.conn_mode = BLE_GAP_CONN_MODE_UND;
    params.disc_mode = BLE_GAP_DISC_MODE_GEN;
    rc = ble_gap_adv_start(own_addr_type, NULL, BLE_HS_FOREVER, &params, gap_event, NULL);
    if (rc != 0 && rc != BLE_HS_EALREADY) {
        printf("adv-error step=start rc=%d\n", rc);
    }
}

static void on_sync(void)
{
    int rc = ble_hs_util_ensure_addr(0);
    assert(rc == 0);
    rc = ble_hs_id_infer_auto(0, &own_addr_type);
    if (rc != 0) {
        printf("adv-error step=address rc=%d\n", rc);
        return;
    }
    printf("ready name=\"%s\"\n", DEVICE_NAME);
    advertise();
}

static void on_reset(int reason)
{
    printf("ble-reset reason=%d\n", reason);
}

static void host_task(void *param)
{
    nimble_port_run();
    nimble_port_freertos_deinit();
}

void app_main(void)
{
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);

    lua = lua_runtime_start();
    if (lua != NULL) {
        lua_runtime_selfcheck(lua);
    }

    ESP_ERROR_CHECK(nimble_port_init());

    ble_hs_cfg.sync_cb = on_sync;
    ble_hs_cfg.reset_cb = on_reset;
    // When the bond store is full, drop the oldest bond to make room.
    ble_hs_cfg.store_status_cb = ble_store_util_status_rr;

    ble_svc_gap_init();
    ble_svc_gatt_init();
    int rc = ble_gatts_count_cfg(gatt_services);
    assert(rc == 0);
    rc = ble_gatts_add_svcs(gatt_services);
    assert(rc == 0);
    rc = ble_svc_gap_device_name_set(DEVICE_NAME);
    assert(rc == 0);

    ble_store_config_init();
    nimble_port_freertos_init(host_task);
}
