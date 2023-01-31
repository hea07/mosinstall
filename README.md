# macOS-Install

⚠️ This scripts is not done. Use at your own responsibility! ⚠️

----

`mosinstall` was made to force a specific version of macOS in the Recovery Mode of Macs. By downloading the installer directly, we can download the version required and run the program from within the Recovery Mode.

`install` will ask you if you want to delete your drive and acts accordingly. On Catalina, I saw on several occasions, that it might have problems deleting the drive. You'll have to delete the drive yourself.

You will be able to choose the macOS Version you want, it downloads that one, sets everything up and runs it on the spot.

Start the setup by running the following in line in the Terminal in Recovery Mode:

```bash
bash < <(curl -s raw.githubusercontent.com/konfigurate/mosinstall/main/install)
```

On Intel, it does not seem to allow downgrades from the Ventura Recovery, might work on M1.

## Recovery → Version Compatibility

|Install → <br>Recovery ↓|Big Sur|Monterey|Ventura
|:--|:-:|:-:|:-:|
|Catalina|✅|✅|✅|
|Big Sur|✅|✅|✅|
|Monterey|✅|✅|✅|
|Ventura|❌|❌|✅|
