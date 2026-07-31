# QuestBoard

QuestBoard is a full-stack application with a Python (FastAPI) backend and a Flutter frontend.

## 1. Start the Backend Server First
Before running the frontend client on any platform, make sure the backend is running.
1. Open a terminal and navigate to the `server` directory.
2. Activate your virtual environment and run the server:
```bash
source .venv/bin/activate
uvicorn app.main:app --reload
```

---

## 2. Running the Flutter Client

Open a new terminal window and navigate to the `client` directory:
```bash
cd client
```

### Option A: Native Desktop (Best for Low-End PCs)
Running natively on your OS provides the best performance and doesn't require any emulator overhead.
* **Linux:** `flutter run -d linux`
* **Windows:** `flutter run -d windows`

### Option B: Web Browser (Extremely Lightweight)
You can run the app directly in your web browser. This is very fast and requires no mobile emulators.
* **Firefox or Brave:** You can run it via a local web server which any browser can access: `flutter run -d web-server`. Then, open the provided localhost URL (e.g., `http://localhost:54321`) in Brave or Firefox.

### Option C: Mobile Testing (Bluetooth, Camera, GPS, etc.)

If you need to test native mobile features, you have two options. Using your own physical phone is highly recommended for low-end PCs because it uses **zero** RAM on your computer compared to an emulator.

#### 1. Physical Android Phone (Highly Recommended for Low-End PC)
This is the absolute best way to test mobile features on a low-end machine.
1. On your Android phone, go to **Settings > About Phone** and tap **Build Number** 7 times to enable Developer Options.
2. Go back to Settings, search for **Developer Options**, and enable **USB Debugging**.
3. Plug your phone into your PC using a USB cable.
4. On your phone, a prompt will appear asking to "Allow USB debugging". Check "Always allow from this computer" and tap OK.
5. In your terminal, run `flutter devices` to ensure your phone is recognized.
6. Run the app on your phone:
   ```bash
   flutter run
   ```
*(Flutter will automatically pick your connected phone. If you have multiple devices, use `flutter run -d <device_id>`)*.

#### 2. AOSP ATD Emulator (Lightweight Emulator)
If you don't have an Android device on hand, you can use the Automated Test Device (ATD) image. It runs headlessly or with a very minimal UI, saving RAM.
1. Install an ATD system image via the Android SDK Manager: `sdkmanager "system-images;android-30;aosp_atd;x86_64"`
2. Create an AVD with it: `avdmanager create avd -n ATD_Device -k "system-images;android-30;aosp_atd;x86_64"`
3. Start the emulator: `emulator -avd ATD_Device`
4. Once the emulator is running, start the app:
   ```bash
   flutter run
   ```
