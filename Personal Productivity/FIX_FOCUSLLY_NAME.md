# Fix "Focuslly" to "Personal Productivity" - Manual Fix Guide

## The Problem
Your Xcode project is trying to install an app called "Focuslly.app" but the project has been renamed to "Personal Productivity". This causes the installation to fail on device.

## The Solution

You need to update the Xcode project settings. Here's the **EASIEST way** to fix this:

---

## RECOMMENDED FIX (Do This First - Takes 2 Minutes)

### Step 1: Rename the Target in Xcode

1. **Open Xcode**
2. **Click on the blue project icon** at the top of the file navigator (it says "Personal Productivity")
3. In the left panel under "TARGETS", you'll see **"Focuslly"**
4. **Click ONCE on "Focuslly"** to select it
5. **Click AGAIN (slowly)** to make the name editable (or press Enter/Return)
6. **Type:** `Personal Productivity`
7. **Press Enter**
8. Xcode will show a dialog: **"Rename scheme 'Focuslly' to 'Personal Productivity'?"**
9. **Click "Rename"**

### Step 2: Clean and Rebuild

1. **Clean Build Folder:**
   - Menu: Product → Clean Build Folder
   - Or keyboard: **Shift + Cmd + K**

2. **Close Xcode completely** (Cmd+Q)

3. **Reopen your project**

4. **Build:**
   - Menu: Product → Build
   - Or keyboard: **Cmd + B**

5. **Run on device:**
   - Menu: Product → Run
   - Or keyboard: **Cmd + R**

---

## IF THAT DOESN'T WORK: Manual Build Settings Fix

### Step 1: Update Product Name

1. Open Xcode
2. Select your project (blue icon)
3. Select the **"Personal Productivity"** target (if you renamed it) or **"Focuslly"** (if rename didn't work)
4. Go to **"Build Settings"** tab
5. In the search bar, type: `PRODUCT_NAME`
6. Find **"Product Name"**
7. **Double-click the value** and change to: `Personal Productivity`
8. Press Enter

### Step 2: Update Bundle Display Name

1. Still in **Build Settings**
2. Search for: `CFBundleDisplayName`
3. Find **"Bundle Display Name"** or look for `INFOPLIST_KEY_CFBundleDisplayName`
4. Change from `Focuslly` to `Personal Productivity`

### Step 3: Clean and Rebuild

1. Product → Clean Build Folder (Shift+Cmd+K)
2. Close Xcode
3. Reopen
4. Build (Cmd+B)
5. Run (Cmd+R)

---

## NUCLEAR OPTION: Delete Derived Data

If the above doesn't work:

1. **Close Xcode completely**

2. **Delete Derived Data:**
   - Open Finder
   - Press **Cmd+Shift+G** (Go to Folder)
   - Paste: `~/Library/Developer/Xcode/DerivedData`
   - Find the folder that starts with **"Personal_Productivity-"**
   - **Delete it** (move to trash)

3. **Reopen Xcode**

4. **Clean Build Folder** (Shift+Cmd+K)

5. **Build** (Cmd+B)

6. **Run** (Cmd+R)

---

## Verify It Worked

After building successfully, check:

1. In Xcode's **Products** folder (in navigator), you should see **"Personal Productivity.app"** (NOT "Focuslly.app")

2. When you run on device, the app icon should say **"Personal Productivity"**

---

## If You're Still Having Issues

The project.pbxproj file needs manual editing. Here's what to do:

### Option A: Use Terminal (Advanced)

1. **Close Xcode**
2. Open Terminal
3. Navigate to project:
   ```bash
   cd "/Users/karlodekanic/Documents/Developer/Personal Productivity/Personal Productivity.xcodeproj"
   ```
4. Backup the project file:
   ```bash
   cp project.pbxproj project.pbxproj.backup
   ```
5. Replace all instances:
   ```bash
   sed -i '' 's/Focuslly/Personal Productivity/g' project.pbxproj
   ```
6. **Reopen Xcode**
7. Clean and rebuild

### Option B: Edit in Text Editor

1. **Close Xcode completely**
2. Right-click on **"Personal Productivity.xcodeproj"** in Finder
3. Select **"Show Package Contents"**
4. Right-click **"project.pbxproj"**
5. Open with **TextEdit** or **VS Code**
6. Press **Cmd+F** to find
7. Search for: `Focuslly`
8. **Replace all** with: `Personal Productivity`
9. **Save** the file
10. **Reopen Xcode**
11. Clean and rebuild

---

## Expected Changes

You should replace **9 instances** of "Focuslly":

1. Line 25: `Focuslly.app` → `Personal Productivity.app`
2. Line 68: `Focuslly.app` → `Personal Productivity.app`
3. Line 76: `/* Focuslly */` → `/* Personal Productivity */`
4. Line 78: `"Focuslly"` → `"Personal Productivity"`
5. Line 92: `name = Focuslly;` → `name = "Personal Productivity";`
6. Line 96: `Focuslly.app` → `Personal Productivity.app`
7. Line 128: `/* Focuslly */` → `/* Personal Productivity */`
8. Line 315: `Focuslly` → `Personal Productivity`
9. Line 350: `"Focuslly"` → `"Personal Productivity"`

---

## WHY THIS HAPPENED

Your project was originally named "Focuslly" and you renamed it to "Personal Productivity". However, renaming the folder and files doesn't automatically update the internal Xcode project settings. The build system still references the old name.

---

## After Fixing

Once fixed, when you build and run:
- ✅ The app will install as "Personal Productivity.app"
- ✅ The home screen icon will say "Personal Productivity"
- ✅ No more installation errors

---

**Start with the RECOMMENDED FIX at the top - it's the easiest and safest!**

Good luck! 🍀
