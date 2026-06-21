# burnOS vendor additions — inherit from panther / lynx device.mk
PRODUCT_PACKAGES -= \
    talkback

PRODUCT_PACKAGES += \
    Burn \
    FDroid \
    ThreemaLibre \
    Zerion \
    WireGuard \
    privapp_permissions_com.burner.tel \
    burn-provision-device-owner.sh \
    burn-provision-fdroid-repos.sh \
    burn-provision-system-defaults.sh \
    burn-provision-carrier-lockdown.sh \
    burn_fdroid_extra_repos \
    BurnIconOverlay

PRODUCT_PRODUCT_PROPERTIES += \
    ro.burn.device_owner.component=com.burner.tel/com.burn.app.service.BurnDeviceAdminReceiver \
    esim.enable_esim_system_ui_by_default=true
