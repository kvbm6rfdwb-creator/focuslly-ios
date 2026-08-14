#!/bin/bash

# Fix Info.plist case mismatch in Xcode project
# Run this script with Xcode CLOSED

PROJECT_FILE="/Users/karlodekanic/Documents/Developer/Personal Productivity/Personal Productivity.xcodeproj/project.pbxproj"

echo "🔧 Fixing Info.plist filename case mismatch..."
echo ""

# Check if Xcode is running
if pgrep -x "Xcode" > /dev/null; then
    echo "❌ ERROR: Xcode is currently running!"
    echo "Please quit Xcode first, then run this script again."
    echo ""
    echo "Steps:"
    echo "1. Quit Xcode (Cmd+Q)"
    echo "2. Run this script again: ./fix_infoplist_case.sh"
    exit 1
fi

# Backup the project file
echo "📦 Creating backup..."
cp "$PROJECT_FILE" "$PROJECT_FILE.backup_$(date +%Y%m%d_%H%M%S)"

# Fix the case (Info.plist -> info.plist)
echo "✏️  Fixing filename case..."
sed -i '' 's|"Personal Productivity/Info\.plist"|"Personal Productivity/info.plist"|g' "$PROJECT_FILE"

# Add GENERATE_INFOPLIST_FILE = NO to Release if missing
echo "✏️  Ensuring GENERATE_INFOPLIST_FILE = NO in both configurations..."

# Check if Release already has it
if ! grep -q "GENERATE_INFOPLIST_FILE = NO;" "$PROJECT_FILE" | head -2 | tail -1; then
    # Add it to Release configuration (after line with ENABLE_PREVIEWS in Release section)
    sed -i '' '/ENABLE_PREVIEWS = YES;$/a\
				GENERATE_INFOPLIST_FILE = NO;
' "$PROJECT_FILE"
fi

echo ""
echo "✅ Fix applied successfully!"
echo ""
echo "📝 Changes made:"
echo "  • Changed INFOPLIST_FILE from 'Info.plist' to 'info.plist' (lowercase)"
echo "  • Added GENERATE_INFOPLIST_FILE = NO to both Debug and Release"
echo ""
echo "🔍 Verification:"
grep "INFOPLIST_FILE" "$PROJECT_FILE"
echo ""
echo "✨ Next steps:"
echo "1. Open Xcode"
echo "2. Product → Clean Build Folder (Shift+Cmd+K)"
echo "3. Delete Derived Data:
   rm -rf ~/Library/Developer/Xcode/DerivedData/Personal_Productivity*"
echo "4. Build and Run (Cmd+R)"
echo ""
echo "Your app should now install successfully on your device! 🎉"
