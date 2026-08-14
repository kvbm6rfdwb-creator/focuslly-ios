# Fix Focuslly Installation Issue - FINAL SOLUTION

## The Root Problem

Your **Debug** build configuration is missing two critical settings that are present in **Release**:

1. `INFOPLIST_FILE = "Personal Productivity/Info.plist";`
2. `INFOPLIST_KEY_CFBundleDisplayName = Focuslly;`

When you run the app from Xcode, it uses **Debug** mode by default. Without these settings, the app builds as "Personal-Productivity.app" but tries to display as something else, causing installation to fail.

## SOLUTION: Fix Build Settings in Xcode

### Step 1: Close Xcode Completely
- Quit Xcode (Cmd+Q)
- Make sure it's fully closed

### Step 2: Fix the Project Configuration

**Option A: Use Xcode UI (Recommended)**

1. **Open Xcode**
2. **Click the blue project icon** at the top of the navigator
3. **Select the "Focuslly" target** (under TARGETS in the middle panel)
4. **Click "Build Settings" tab** at the top
5. **Make sure "All" and "Combined" are selected** (not "Basic" or "Customized")
6. **Search for:** `Info.plist File`
7. **You'll see it has a value for Release but NOT for Debug**
8. **Click on the Debug row** and add: `Personal Productivity/Info.plist`
9. **Search for:** `CFBundleDisplayName`
10. **Click on the empty Debug row** and add: `Focuslly`

### Step 3: Clean and Rebuild

1. **Clean Build Folder** (Product → Clean Build Folder or Shift+Cmd+K)
2. **Quit Xcode again** (Cmd+Q)
3. **Reopen Xcode**
4. **Build and Run** (Cmd+R)

---

## Option B: Manual File Edit (If Option A Doesn't Work)

If you can't modify in Xcode UI, follow these steps:

### Step 1: Quit Xcode Completely
```bash
# Run this in Terminal to make sure Xcode is closed
killall Xcode
```

### Step 2: Edit the Project File Manually

1. Open Terminal
2. Navigate to your project:
```bash
cd "/Users/karlodekanic/Documents/Developer/Personal Productivity"
```

3. Make a backup:
```bash
cp "Personal Productivity.xcodeproj/project.pbxproj" "Personal Productivity.xcodeproj/project.pbxproj.backup"
```

4. Open the file in a text editor (TextEdit or nano):
```bash
nano "Personal Productivity.xcodeproj/project.pbxproj"
```

5. Find this section (around line 282):
```
GENERATE_INFOPLIST_FILE = YES;
INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
```

6. Change it to:
```
GENERATE_INFOPLIST_FILE = YES;
INFOPLIST_FILE = "Personal Productivity/Info.plist";
INFOPLIST_KEY_CFBundleDisplayName = Focuslly;
INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
```

7. Save and exit:
   - If using nano: Press Ctrl+X, then Y, then Enter
   - If using TextEdit: Just save normally

### Step 3: Verify the Fix

Open the file again and search for "Debug" configuration (around line 273-303). You should see:

```
FC7C19942F05531700E65175 /* Debug */ = {
    isa = XCBuildConfiguration;
    buildSettings = {
        ...
        GENERATE_INFOPLIST_FILE = YES;
        INFOPLIST_FILE = "Personal Productivity/Info.plist";
        INFOPLIST_KEY_CFBundleDisplayName = Focuslly;
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
        ...
    };
};
```

### Step 4: Reopen and Build

1. Open Xcode
2. Clean Build Folder (Shift+Cmd+K)
3. Build and Run (Cmd+R)

---

## What This Fixes

**Before (Debug config):**
- ❌ No display name set → app name is "Personal-Productivity"
- ❌ No Info.plist path → can't find OpenAI key
- ❌ Installation fails with domain error

**After (Debug config):**
- ✅ Display name = "Focuslly"
- ✅ Info.plist path points to correct file
- ✅ App installs successfully as "Focuslly"
- ✅ Vision Board can access OpenAI API key

---

## Expected Result

After this fix:
- ✅ App builds successfully
- ✅ App installs on device as "Focuslly"
- ✅ All features work including Vision Board
- ✅ No more "Failed to install" errors

---

## If It Still Fails

If you still get installation errors after this:

1. **Check your device:**
   - Delete any old "Personal Productivity" or "Focuslly" apps already on your device
   - Restart your iPhone/iPad

2. **Check your provisioning:**
   - Make sure your Apple Developer account is set up
   - Device is registered in your developer portal

3. **Share the exact error:**
   - Copy the full error message from Xcode
   - Let me know what it says

This should definitely fix the installation issue!
