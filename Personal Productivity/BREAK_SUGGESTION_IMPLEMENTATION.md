/**
 # Break Suggestion Engine Implementation

 ## Overview
 The Break Suggestion Engine is a sophisticated AI-powered system that analyzes multiple contextual factors during break mode to provide personalized activity suggestions to users. This helps optimize recovery and maintain productivity throughout the day.

 ## Components

 ### 1. BreakSuggestionEngine.swift
 **Purpose**: Core logic for analyzing break context and generating suggestions

 **Key Classes**:
 - `BreakSuggestionEngine`: Main decision-making engine
 - `BreakActivity`: Enum for 10 different break activities
   - hydrate, stretch, walk, breathe, eyes, music, snack, social, rest, focusBreak
 - `EnergyLevel`: User's current energy state (low, medium, high)
 - `Suggestion`: Individual activity recommendation with confidence score
 - `Decision`: Complete break suggestion decision with primary + secondary suggestions

 **Main Method**: `BreakSuggestionEngine.decide()`
 Parameters:
 - `completedTask`: FocusTask that was just finished
 - `engine`: FocusSessionEngine with current session state
 - `breakDuration`: Total break time in seconds
 - `taskStore`: TaskStore for accessing session history

 **Factors Analyzed**:
 1. **Time of Day**: Early morning, morning, afternoon, evening, night
 2. **Break Duration**: Very short (0-3m), short (3-7m), medium (7-15m), long (15m+)
 3. **Completed Task Difficulty**: 1 (low) - 3 (high)
 4. **Next Task Difficulty**: Based on task duration and category
 5. **Prior Breaks Today**: Count and pattern of previous breaks
 6. **Energy Assessment**: Calculated from fatigue, breaks taken, task difficulty, time of day
 7. **Activity Frequency**: Tracks what types of activities have been done today

 **Suggestion Generation Algorithm**:
 1. Generate activity suggestions based on context
 2. Score each suggestion using multiple weighted factors
 3. Sort by confidence score
 4. Return primary + 2 secondary suggestions
 5. Build contextual message explaining the recommendation

 ### 2. BreakSuggestionView.swift
 **Purpose**: SwiftUI component to display suggestions to users

 **Features**:
 - Primary suggestion card with icon, description, confidence score
 - Contextual overall message
 - Secondary suggestions as alternative options
 - Energy level indicator (low/medium/high)
 - "Start Activity" buttons for each suggestion
 - Responsive layout for different screen sizes

 **User Interactions**:
 - User can dismiss the suggestion sheet
 - User can select primary suggestion
 - User can select from secondary suggestions
 - Selection is logged for future learning

 ### 3. FocusView.swift Integration
 **State Management**:
 - `@State private var breakSuggestionDecision`: Stores the decision from engine
 - `@State private var showBreakSuggestion`: Controls sheet visibility
 - `@State private var hasShownBreakSuggestion`: Prevents showing suggestion twice per break

 **Key Changes**:
 - Added `.sheet(isPresented: $showBreakSuggestion)` to display suggestions
 - Added `.onChange(of: engine.blockType)` to detect when break mode starts
 - When blockType changes to .breakTime, automatically generates and shows suggestion (0.5s delay for animation)
 - Suggestion appears after focus timer completes/user enters break mode

 **Integration Points**:
 ```
 Focus Completed
      ↓
 Focus Summary Sheet
      ↓
 User clicks "Done" → engine.startBreakAfterSummary()
      ↓
 blockType changes to .breakTime (observed by onChange)
      ↓
 BreakSuggestionEngine.decide() called
      ↓
 BreakSuggestionView displayed
      ↓
 User selects activity / dismisses
      ↓
 Break timer runs
      ↓
 User can stop break anytime
   ```

 **Logging**:
 - `logBreakActivitySelection()`: Records which suggestion the user selected
 - Data stored in UserDefaults under "break_activity_selection_logs_v1"
 - Used for analytics and future machine learning improvements

 ## Activity Recommendations Logic

 The engine determines which activities to suggest based on context:

 ### Physical Movement Activities (stretch, walk)
 - Priority when: High energy, after difficult tasks, sedentary (few prior movements)
 - Duration: Stretch (3m) or Walk (10m for longer breaks)

 ### Eye Care (eyes)
 - Always suggested in afternoon/evening (screen fatigue)
 - Confidence: 0.90 (high)

 ### Hydration (hydrate)
 - When: Low energy, difficult task, few prior nutrition breaks
 - Quick activity (2m)

 ### Breathing/Meditation (breathe)
 - When: High task difficulty or low energy
 - Duration: 2-5m depending on break length

 ### Music (music)
 - When: Low energy in medium/long breaks
 - Boosts mood without requiring movement

 ### Social Interaction (social)
 - When: Long breaks with few social activities
 - Provides mental refreshment

 ### Nutrition (snack)
 - When: Meal times (morning/afternoon), few prior snacks
 - Light snack to sustain energy

 ### Rest (rest)
 - High priority when: Very fatigued, long/medium breaks
 - Confidence: 0.85

 ### Light Learning (focusBreak)
 - When: Next task is easy and energy is high
 - Eases transition to next task

 ## Energy Level Calculation

 ```
 baseScore = 10
 Reduce by:
   - 1-3 points: Based on focus time today (60m/120m/180m+)
   - 1-2 points: Based on task difficulty
   - 1-3 points: Based on time of day (evening/night worst)
 Increase by:
   - 1-2 points: Based on breaks already taken (3+/5+ breaks)

 Result:
   - 12+ : HIGH energy
   - 8-11 : MEDIUM energy
   - <8  : LOW energy
 ```

 ## Confidence Scoring

 Each suggestion is scored based on:
 1. Base confidence (0.68 - 0.90 depending on activity type)
 2. Duration fit multiplier (0.8 - 1.1)
 3. Energy level boost (0.8 - 1.2)
 4. Activity variety bonus (1.0 - 1.1 based on frequency)
 5. Task transition boost (1.15 for difficult next task)

 Suggestions are ranked by score and top 3 are returned (1 primary + 2 secondary).

 ## Performance Considerations

 - **Lazy Evaluation**: No suggestions are generated until break mode is entered
 - **Caching**: Engine.task and prior session logs are cached/not recomputed
 - **Async Dispatch**: Suggestion generation delayed 0.5s to avoid animation jank
 - **Memory**: UserDefaults used for logging (small, bounded data)
 - **CPU**: Activity scoring is O(N) where N = number of activities (~10)

 ## Data Flow

 ```
 User completes focus session
     ↓
 FocusSessionEngine.finishFocusAndAwaitBreak()
     ↓
 [Focus Summary shown]
     ↓
 User clicks "Done" button
     ↓
 FocusView:
   - Calls engine.startBreakAfterSummary()
   - Detects blockType change via onChange
   - Generates suggestion via BreakSuggestionEngine.decide()
   - Shows BreakSuggestionView sheet
     ↓
 User interacts:
   - Selects primary suggestion
   - OR selects secondary suggestion
   - OR dismisses sheet
     ↓
 Activity is logged
 Break timer continues running
     ↓
 User completes break or stops manually
 ```

 ## Error Handling

 - If no task found: Returns safe default (rest for 2-5m)
 - If taskStore is nil: Uses data from engine only
 - If breakDuration is 0: Clamps to minimum reasonable duration
 - If no suggestions generated: Adds default rest suggestion
 - If energy calculation fails: Defaults to MEDIUM

 ## Future Enhancements

 1. **Machine Learning**: Track which suggestions users choose and improve recommendations
 2. **Activity History**: Remember user's preferred activities during breaks
 3. **Category-Specific Logic**: Different suggestions for different task categories
 4. **Weather Integration**: Suggest walk more when weather is good
 5. **Social Context**: Suggest social activities when colleagues are visible
 6. **Biometric Data**: Integrate heart rate / stress levels for better energy assessment
 7. **Break Effectiveness Tracking**: Measure which activities actually improve focus in next session

 ## Testing

 Preview included in BreakSuggestionView.swift showing:
 - Primary suggestion (Stretch at 88% confidence)
 - 2 secondary suggestions (Hydrate and Eye rest)
 - Energy level indicator
 - All visual elements

 To test end-to-end:
 1. Start a focus session
 2. Let it complete or manually finish
 3. Click "Done" on summary
 4. Break suggestion sheet appears with personalized recommendations
 5. Select an activity
 6. Verify activity is logged in UserDefaults

 ## Code Quality

 - ✅ No errors in compilation
 - ✅ No breaking changes to existing flow
 - ✅ Type-safe enum-based activities
 - ✅ Comprehensive documentation
 - ✅ Proper resource cleanup (flag resets)
 - ✅ Logging for analytics and debugging
 - ✅ Respects existing break feedback mechanism
 - ✅ Handles edge cases (nil checks, bounds checking)
 - ✅ Follows Apple design patterns (SF Symbols, system colors)
 */
