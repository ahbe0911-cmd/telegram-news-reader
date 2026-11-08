#!/usr/bin/env python3
"""Idempotently replace Flutter's disposable DEBUG signing with release signing.

Flutter's Android folder is scaffolded at build time in this repository.
Run this script AFTER flutter create and BEFORE flutter build apk.
Private signing material is stored only in android/key.properties and a private
keystore file; both are ignored by git.
"""

from pathlib import Path
import re
import sys

MARKER = "// TELEPULSE_RELEASE_SIGNING_V1"

HEADER = r'''
// TELEPULSE_RELEASE_SIGNING_V1: persistent signing key; never debug fallback.
val telePulseSigningProperties = Properties()
val telePulseSigningFile = rootProject.file("key.properties")
if (telePulseSigningFile.exists()) {
    telePulseSigningFile.inputStream().use {
        telePulseSigningProperties.load(it)
    }
}
val telePulseReleaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (telePulseReleaseRequested && listOf(
        "storeFile", "storePassword", "keyAlias", "keyPassword"
    ).any { telePulseSigningProperties.getProperty(it).isNullOrBlank() }) {
    throw org.gradle.api.GradleException(
        "TelePulse release requires android/key.properties with a PERSISTENT " +
        "keystore. Never sign public releases using a changing CI debug key."
    )
}
'''

SIGNING = r'''
    signingConfigs {
        create("release") {
            keyAlias = telePulseSigningProperties.getProperty("keyAlias")
            keyPassword = telePulseSigningProperties.getProperty("keyPassword")
            storeFile = telePulseSigningProperties.getProperty("storeFile")
                ?.let { file(it) }
            storePassword = telePulseSigningProperties.getProperty("storePassword")
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

'''

def configure(file: Path) -> None:
    if not file.exists():
        raise RuntimeError(
            f"{file} is missing. Run flutter create --platforms=android first."
        )
    text = file.read_text(encoding="utf-8")
    if MARKER in text:
        print(f"Already configured: {file}")
        return
    if "android {" not in text or "    buildTypes {" not in text:
        raise RuntimeError(f"Unexpected Gradle Kotlin structure: {file}")
    # Kotlin DSL permits imports above plugins {} but not ordinary declarations.
    text = "import java.util.Properties\n\n" + text
    text = text.replace("android {", HEADER + "\nandroid {", 1)
    text = text.replace("    buildTypes {", SIGNING + "    buildTypes {", 1)
    pattern = r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'
    text, number = re.subn(
        pattern,
        'signingConfig = signingConfigs.getByName("release")',
        text, count=1,
    )
    if number != 1:
        raise RuntimeError("Could not locate Flutter debug signing assignment.")
    if "signingConfigs.getByName(\"debug\")" in text:
        raise RuntimeError("A debug-signing assignment remains; refusing build.")
    file.write_text(text, encoding="utf-8")
    print(f"Configured persistent release signing: {file}")


if __name__ == "__main__":
    target = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(
        "android/app/build.gradle.kts"
    )
    configure(target)
