/**
 # Break Suggestion UX Specification

 ## Visual Design

 ### BreakSuggestionView Layout

 ```
 ┌─────────────────────────────────────┐
 │  Break Suggestion        [x]        │  (Header with dismiss)
 ├─────────────────────────────────────┤
 │                                     │
 │  What's best for you right now?     │  (Subheading)
 │  ────────────────────────────────── │
 │  You've been working hard. A good   │
 │  stretch will help you feel         │
 │  refreshed. Afternoon focus can be  │
 │  harder—recharge well. You have     │  (Contextual Message)
 │  good energy—use it wisely.         │
 │                                     │
 ├─────────────────────────────────────┤
 │                                     │
 │  ┌──────────────────────────────┐   │
 │  │ 🧘 Stretch                   │88% │  (Primary Card)
 │  │ Loosen up your muscles and   │   │
 │  │ improve circulation.          │   │
 │  │ Physical movement helps      │   │
 │  │ recovery after intense focus │   │
 │  └──────────────────────────────┘   │
 │                                     │
 │  [    Start Stretch    ]            │  (Action Button - Red)
 │                                     │
 ├─────────────────────────────────────┤
 │  Or try                             │
 │  ────────────────────────────────── │
 │                                     │
 │  [ 💧 Hydrate                 → ]   │  (Secondary Option 1)
 │    Drink some water to refresh...   │
 │                                     │
 │  [ 👁️ Rest Your Eyes          → ]   │  (Secondary Option 2)
 │    Look away from the screen...     │
 │                                     │
 ├─────────────────────────────────────┤
 │  Your Energy          🔋 Medium     │  (Energy Indicator)
 ├─────────────────────────────────────┤

 ```

 ## Color Scheme

 - **Primary Button**: Apple Red (Color(red: 1.0, green: 0.23, blue: 0.19))
 - **Secondary Buttons**: System Gray 6 background
 - **Icons**: Apple Red (SF Symbols)
 - **Energy Indicator**:
   - Low: Red (battery.25)
   - Medium: Orange (battery.50)
   - High: Green (battery.100)
 - **Text**:
   - Primary: .primary
   - Secondary: .secondary
   - Tertiary: .tertiary

 ## Typography

 - Header: System 17pt, Semibold
 - Question: System 15pt, Semibold
 - Descriptions: System 13-14pt, Regular
 - Reasons: System 12pt, Regular

 ## Activity Icons

 - hydrate → cup.and.saucer.fill
 - stretch → figure.flexibility
 - walk → figure.walk
 - breathe → lungs.fill
 - eyes → eye.fill
 - music → music.note
 - snack → fork.knife
 - social → person.2.fill
 - rest → moon.zzz.fill
 - focusBreak → book.fill

 ## User Journey

 ```
 Step 1: Focus Completes
   ↓
 [Timer reaches 00:00 with celebration animation]
   ↓
 Step 2: Focus Summary Sheet Appears
   [Shows task summary, duration, exit reason]
   [Primary: "Done" - continues to break]
   [Secondary: "Continue break" - if recommended]
   ↓
 Step 3: User Clicks "Done"
   ↓
 [Summary sheet closes]
 [0.5 second delay for smooth animation]
   ↓
 Step 4: Break Mode Starts
   ↓
 [Timer begins for break duration]
 [Break suggestion sheet appears with recommendations]
   ↓
 Step 5: User Interacts with Suggestion
   
   Option A: User Taps "Start [Activity]"
     - Activity selection logged
     - Sheet closes
     - Break continues with timer
     - Break ends naturally or user stops manually
   
   Option B: User Taps Secondary Suggestion
     - Different activity selected
     - Same flow as Option A
   
   Option C: User Dismisses Sheet
     - Break continues normally
     - No activity logged
     - Break feedback shows at end

   ↓
 Step 6: Break Completes
   ↓
 [Break feedback sheet: "How was that break?"]
 [Options: "Too short" / "Just right" / "Too long"]
   ↓
 Step 7: Break Summary
   [Shows break duration, next task options]
   [Primary: "Finish" - exit focus flow]
   [Secondary: "Next task" - chain to next task]
   ↓
 Complete
 ```

 ## Presentation Style

 - **Sheet Type**: UISheetPresentationController
 - **Detents**: [.medium, .large] - allows expansion
 - **Drag Indicator**: Visible
 - **Dismissal**: User can dismiss by swiping down

 ## Accessibility

 - All buttons have clear labels
 - Icons paired with text descriptions
 - High contrast for energy indicator
 - VoiceOver compatible (text-based)
 - Sufficient touch targets (44pt minimum)

 ## Animation Timing

 - Sheet appearance: 0.3s delay after focus summary
 - Button tap feedback: Instant
 - Color transitions: Smooth, spring-based
 - No excessive animations (respects reduced motion)

 ## Responsive Design

 - Adapts to:
   - iPhone SE to Pro Max (width: 375 - 430pt)
   - Portrait and landscape (if needed)
   - Split view on iPad
   - Dynamic Type sizes (Accessibility)

 ## States

 ### Initial State
 - Sheet hidden
 - No suggestion decision

 ### Showing Suggestion
 - Sheet visible
 - Primary suggestion highlighted
 - Secondary options visible
 - Energy indicator displayed

 ### After Selection
 - Sheet animates away
 - Activity logged
 - Return to break timer view

 ### Edge Cases Handled
 - No next task: Only shows "Finish" option
 - Long break: Shows more detailed suggestions
 - Very short break: Suggests quick activities only
 - Low energy: Emphasizes rest/breathing
 - High energy: Emphasizes movement/social

 ## Interaction Feedback

 - Button press: Subtle scale down + immediate action
 - Dismissal: Swipe gesture with momentum
 - Activity selection: Haptic feedback (if enabled)
 - Visual confirmation of selection via logging

 ## Theme Support

 - Light mode: Full color support
 - Dark mode: Adapts automatically
 - High contrast: SF Symbols scale appropriately
 - No custom colors that require theme awareness

 ## Loading States

 - Suggestion generation: Hidden (0.5s async delay)
 - No loading spinner (engine runs fast)
 - Smooth appearance without jank

 ## Error States

 - If no suggestion generated: Shows default "Rest" option
 - If taskStore unavailable: Uses engine data only
 - Graceful degradation: Always shows something useful

 */
