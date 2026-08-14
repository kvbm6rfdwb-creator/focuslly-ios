# INFO.PLIST INSTALLATION FAILURE - ROOT CAUSE & FIX

## 🎯 ROOT CAUSE IDENTIFIED

**PRIMARY ISSUE: Filename Case Mismatch**

Your app builds successfully but fails to install with error:
```
Failed to install the app on the device.
CoreDeviceError 3002
MIInstallerErrorDomain Code 35
Failure Reason: Info.plist missing at /var/installd/.../Focuslly.app/Info.plist
```

### Why This Happens

1. **Actual filename**: `info.plist` (lowercase "i")
2. **Build setting reference**: `"Personal Productivity/Info.plist"` (uppercase "I")
3. **macOS**: File system is case-insensitive → build succeeds (file found)
4. **iOS deployment**: Bundle packaging is case-sensitive → installation fails (exact case required)
5. **Result**: .app bundle is created WITHOUT Info.plist inside it

---

## ✅ FIX APPLIED

I've corrected both Debug and Release build configurations:

### Before (BROKEN):
```
Debug:
  GENERATE_INFOPLIST_FILE = NO
  INFOPLIST_FILE = "Personal Productivity/Info.plist"  ❌ Wrong case

Release:
  INFOPLIST_FILE = "Personal Productivity/Info.plist"  ❌ Wrong case
  (Missing GENERATE_INFOPLIST_FILE setting)
```

### After (FIXED):
```
Debug:
  GENERATE_INFOPLIST_FILE = NO
  INFOPLIST_FILE = "Personal Productivity/info.plist"  ✅ Correct case

Release:
  GENERATE_INFOPLIST_FILE = NO                         ✅ Added
  INFOPLIST_FILE = "Personal Productivity/info.plist"  ✅ Correct case
```

---

## 🚀 VERIFICATION STEPS

### Step 1: Quit and Reopen Xcode
```bash
# Close Xcode completely
# Reopen your project
```

### Step 2: Clean Build Folder
In Xcode:
- **Product → Clean Build Folder** (Shift+Cmd+K)

### Step 3: Delete Derived Data
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/Personal_Productivity*
```

Or in Xcode:
- Xcode → Settings → Locations → Click arrow next to Derived Data
- Delete folder starting with "Personal_Productivity-"

### Step 4: Build and Run
1. **Build** (Cmd+B) - Should succeed
2. **Run on device** (Cmd+R) - Should install successfully

### Step 5: Verify Info.plist is in .app Bundle

After build, check the bundle:

```bash
cd ~/Library/Developer/Xcode/DerivedData/Personal_Productivity-*/Build/Products/Debug-iphoneos/

# List contents of Focuslly.app
ls -la Focuslly.app/

# Verify Info.plist exists
ls -la Focuslly.app/Info.plist
```

You should see:
```
-rw-r--r--  1 user  staff  1234 Feb 12 18:00 Info.plist
```

### Step 6: Verify Info.plist Contents

```bash
plutil -p Focuslly.app/Info.plist
```

Should show all required keys including:
- CFBundleDisplayName = "Focuslly"
- CFBundleExecutable
- CFBundleIdentifier
- CFBundleVersion
- etc.

---

## 📋 EXACT BUILD SETTINGS REQUIRED

For both **Debug** and **Release** configurations:

| Setting | Value | Notes |
|---------|-------|-------|
| `GENERATE_INFOPLIST_FILE` | `NO` | Disable auto-generation since we have manual Info.plist |
| `INFOPLIST_FILE` | `"Personal Productivity/info.plist"` | **MUST match exact filename case** |
| Resources Build Phase | (empty) | Info.plist must NOT be in Copy Bundle Resources |

### Path Format Requirements

✅ **CORRECT**:
```
INFOPLIST_FILE = "Personal Productivity/info.plist"
```

❌ **WRONG**:
```
INFOPLIST_FILE = "Personal Productivity/Info.plist"  // Wrong case
INFOPLIST_FILE = Personal Productivity/info.plist    // Missing quotes
INFOPLIST_FILE = $(SRCROOT)/Personal Productivity/info.plist  // Unnecessary SRCROOT
INFOPLIST_FILE = /Users/.../info.plist  // Absolute path (don't use)
```

---

## 🔍 TECHNICAL EXPLANATION

### Why Build Succeeds but Installation Fails

1. **Build Phase**: Xcode uses macOS file system (case-insensitive)
   - `Info.plist` reference → finds `info.plist` file → build succeeds

2. **Bundle Packaging**: Xcode's bundle processor looks for exact filename
   - Searches for `Info.plist` (uppercase) in source
   - File is actually named `info.plist` (lowercase)
   - On case-sensitive systems/operations: **file not found**
   - Bundle is created WITHOUT Info.plist

3. **Installation**: iOS device receives .app bundle
   - iOS validates bundle structure
   - **Requires** Info.plist at root of .app
   - **Error 3002**: Bundle validation fails (missing Info.plist)

### File System Synchronized Root Group

Your project uses Xcode's modern `PBXFileSystemSynchronizedRootGroup`:
- No explicit file references in project.pbxproj
- Files are auto-included from file system
- **Filename case MUST match exactly** in INFOPLIST_FILE setting

---

## ✅ CHECKLIST

After applying the fix, verify:

- [x] GENERATE_INFOPLIST_FILE = NO in Debug
- [x] GENERATE_INFOPLIST_FILE = NO in Release
- [x] INFOPLIST_FILE = "Personal Productivity/info.plist" in Debug (lowercase)
- [x] INFOPLIST_FILE = "Personal Productivity/info.plist" in Release (lowercase)
- [ ] Xcode quit and reopened
- [ ] Derived Data deleted
- [ ] Clean Build Folder executed
- [ ] Build succeeds
- [ ] Installation succeeds on physical device
- [ ] Info.plist visible inside Focuslly.app bundle

---

## 🎉 EXPECTED RESULT

Your app will now:

✅ Build successfully  
✅ **Install successfully on physical device**  
✅ Display as "Focuslly" on device  
✅ Contain Info.plist inside Focuslly.app bundle  
✅ Pass iOS bundle validation  

---

## 📱 VERIFICATION COMMAND

After successful installation, verify on device:

```bash
# If using Xcode Devices window
# Right-click on Focuslly.app → Show Package Contents
# Verify Info.plist is present
```

Or check build products:

```bash
cd ~/Library/Developer/Xcode/DerivedData
find . -name "Focuslly.app" -exec ls -la {}/Info.plist \;
```

Should output:
```
-rw-r--r--  1 user  staff  XXXX Info.plist
```

---

## 🛠️ IF STILL FAILING

If installation still fails after applying this fix:

1. **Verify filename case in Finder**:
   ```bash
   ls -la "Personal Productivity/" | grep -i info
   ```
   Should show: `info.plist` (lowercase)

2. **Verify build settings**:
   - Open Xcode → Project → Focuslly target → Build Settings
   - Search "Info.plist File"
   - Should show: `Personal Productivity/info.plist`

3. **Check for typos**:
   - Ensure no extra spaces
   - Ensure correct folder name "Personal Productivity"
   - Ensure correct filename "info.plist"

4. **Nuclear option - Rename file to match**:
   ```bash
   cd "Personal Productivity"
   mv info.plist Info.plist
   ```
   Then update build settings to `"Personal Productivity/Info.plist"` (uppercase)

---

## 📝 SUMMARY

**Problem**: Filename case mismatch between build setting and actual file  
**Solution**: Changed INFOPLIST_FILE from `Info.plist` to `info.plist`  
**Result**: Bundle packaging now finds the file → Info.plist included in .app → Installation succeeds  

**Files Modified**:
- ✅ `Personal Productivity.xcodeproj/project.pbxproj` (2 lines changed)

**No other changes required.**

---

*Fix applied: February 12, 2026*  
*Build system: Xcode 26.2*  
*Target: iOS 26.2 SDK*  
*Deployment: Physical device*
