#!/usr/bin/env python3
"""burnOS — branding + use & liability on Settings About phone screens."""
from __future__ import annotations

import sys
from pathlib import Path

LIABILITY_MARKER = 'android:key="burn_use_liability"'
BRANDING_MARKER = 'android:key="burn_about_branding"'
LEGAL_BRANDING_MARKER = 'android:key="burn_legal_branding"'

MY_DEVICE_BRANDING = """
    <com.android.settingslib.widget.LayoutPreference
        android:key="burn_about_branding"
        android:layout="@layout/burn_about_header"
        android:order="0"
        android:selectable="false"/>
"""

MY_DEVICE_PREF = """        <!-- burnOS use & liability -->
        <Preference
            android:key="burn_use_liability"
            android:order="10"
            android:title="@string/burn_use_liability_title"
            android:summary="@string/burn_use_liability_summary"
            android:fragment="com.android.settings.deviceinfo.aboutphone.BurnUseLiabilityFragment"/>
"""

ABOUT_LEGAL_BRANDING = """
    <com.android.settingslib.widget.LayoutPreference
        android:key="burn_legal_branding"
        android:layout="@layout/burn_legal_header"
        android:order="1"
        android:selectable="false" />
"""

ABOUT_LEGAL_PREF = """    <!-- burnOS use & liability -->
    <Preference
        android:key="burn_use_liability"
        android:order="5"
        android:title="@string/burn_use_liability_title"
        android:summary="@string/burn_use_liability_summary"
        android:fragment="com.android.settings.deviceinfo.aboutphone.BurnUseLiabilityFragment" />

"""


def patch_xml(path: Path, marker: str, insert_after: str, block: str, label: str) -> bool:
    text = path.read_text(encoding="utf-8")
    if marker in text:
        print(f"    already patched ({label}): {path}")
        return False
    if insert_after not in text:
        raise SystemExit(f"{label}: anchor not found in {path}")
    updated = text.replace(insert_after, insert_after + block, 1)
    path.write_text(updated, encoding="utf-8")
    print(f"    patched {label}: {path}")
    return True


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <sync-dir>")

    settings = Path(sys.argv[1]) / "packages/apps/Settings"
    if not settings.is_dir():
        print("    skip: Settings not synced yet")
        return

    my_device = settings / "res/xml/my_device_info.xml"
    about_legal = settings / "res/xml/about_legal.xml"

    if my_device.is_file():
        patch_xml(
            my_device,
            BRANDING_MARKER,
            '        settings:isPreferenceVisible="false"/>',
            MY_DEVICE_BRANDING,
            "my_device_info branding header",
        )
        patch_xml(
            my_device,
            LIABILITY_MARKER,
            '        android:title="@string/my_device_info_legal_category_title">',
            "\n" + MY_DEVICE_PREF,
            "my_device_info legal category",
        )

    if about_legal.is_file():
        patch_xml(
            about_legal,
            LEGAL_BRANDING_MARKER,
            '                  android:title="@string/legal_information">',
            ABOUT_LEGAL_BRANDING,
            "about_legal branding header",
        )
        patch_xml(
            about_legal,
            LIABILITY_MARKER,
            '    <!-- Copyright information -->',
            ABOUT_LEGAL_PREF,
            "about_legal use & liability",
        )


if __name__ == "__main__":
    main()
