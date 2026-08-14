# 🎯 QUICK FIX GUIDE - Info.plist Installation Failure

## THE PROBLEM
✅ App builds successfully  
❌ App fails to install on device  
❌ Error: "Info.plist missing at .../Focuslly.app/Info.plist"

## ROOT CAUSE
**Filename case mismatch:**
- Build setting says: `Info.plist` (uppercase I)
- Actual filename is: `info.plist` (lowercase i)
- Result: Bundle built WITHOUT Info.plist inside it

## THE FIX (3 STEPS)

### Step 1: Quit Xcode
```
Cmd+Q to quit Xcode completely
```

### Step 2: Run Fix Script
```bash
cd "/Users/karlodekanic/Documents/Developer/Personal Productivity"
chmod +x fix_infoplist_case.sh
./fix_infoplist_case.sh
```

### Step 3: Clean and Rebuild
```bash
# Delete Derived Data
rm -rf ~/Library/Developer/Xcode/DerivedData/Personal_Productivity*

# Reopen Xcode, then:
# - Product → Clean Build Folder (Shift+Cmd+K)
# - Product → Run (Cmd+R)
```

## DONE! ✅
Your app will now install successfully on your device.

---

## WHAT THE SCRIPT DOES

Changes this:
```
❌ INFOPLIST_FILE = "Personal Productivity/Info.plist"
```

To this:
```
✅ INFOPLIST_FILE = "Personal Productivity/info.plist"
```

(Matches actual filename case)

---

## VERIFICATION

After running the script, you should see:
```
✅ Fix applied successfully!
```

Then in Xcode Build Settings:
- Search: "Info.plist File"
- Should show: `Personal Productivity/info.plist` (lowercase)

---

## IF YOU PREFER MANUAL FIX

1. Quit Xcode
2. Edit `Personal Productivity.xcodeproj/project.pbxproj`
3. Find (2 occurrences):
   ```
   INFOPLIST_FILE = "Personal Productivity/Info.plist";
   ```
4. Replace with:
   ```
   INFOPLIST_FILE = "Personal Productivity/info.plist";
   ```
5. Save, reopen Xcode, clean, rebuild

---

## DETAILED DOCUMENTATION

See: `INFO_PLIST_DIAGNOSIS_COMPLETE.md` for full technical analysis

---

**Fix Status**: ✅ Ready to apply  
**Time Required**: 2 minutes  
**Files Modified**: 1 (project.pbxproj)  
**Risk Level**: Low (backup created automatically)
