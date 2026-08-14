import SwiftUI

// MARK: - Vision Board Testing Helper
// Use this to quickly test and verify the vision board functionality

struct VisionBoardTestingView: View {
    @StateObject private var visionStore = VisionBoardStore()
    @State private var testResults: [String] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section("Test Results") {
                    ForEach(testResults, id: \.self) { result in
                        HStack {
                            if result.contains("✅") {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if result.contains("❌") {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            Text(result)
                                .font(.caption)
                        }
                    }
                }
                
                Section("Quick Tests") {
                    Button("Test 1: Check Categories") {
                        testCategories()
                    }
                    
                    Button("Test 2: Check Initial Questions") {
                        testInitialQuestions()
                    }
                    
                    Button("Test 3: Add Sample Answer") {
                        testAddAnswer()
                    }
                    
                    Button("Test 4: Get Today's Questions") {
                        testTodaysQuestions()
                    }
                    
                    Button("Test 5: Generate Follow-up Questions") {
                        testGenerateFollowup()
                    }
                    
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .foregroundColor(.red)
                }
                
                Section("Statistics") {
                    Text("Categories: \(visionStore.categories.count)")
                    Text("Questions: \(visionStore.questions.count)")
                    Text("Answers: \(visionStore.answers.count)")
                    Text("Daily Logs: \(visionStore.dailyLogs.count)")
                }
            }
            .navigationTitle("Vision Board Tests")
            .toolbar {
                Button("Clear Results") {
                    testResults.removeAll()
                }
            }
        }
    }
    
    // MARK: - Test Functions
    
    private func testCategories() {
        testResults.append("ℹ️ Testing categories...")
        
        if visionStore.categories.isEmpty {
            testResults.append("❌ No categories found")
            return
        }
        
        testResults.append("✅ Found \(visionStore.categories.count) categories")
        
        let defaultCategories = ["Cars", "Houses", "Career", "Health", "Relationships", "Finances", "Travel", "Learning"]
        for categoryName in defaultCategories {
            if visionStore.categories.contains(where: { $0.name == categoryName }) {
                testResults.append("✅ \(categoryName) category exists")
            } else {
                testResults.append("❌ \(categoryName) category missing")
            }
        }
    }
    
    private func testInitialQuestions() {
        testResults.append("ℹ️ Testing initial questions...")
        
        if visionStore.questions.isEmpty {
            testResults.append("❌ No questions found")
            return
        }
        
        testResults.append("✅ Found \(visionStore.questions.count) questions")
        
        let questionsByCategory = Dictionary(grouping: visionStore.questions, by: { $0.categoryId })
        testResults.append("✅ Questions distributed across \(questionsByCategory.count) categories")
        
        // Check if each category has at least one question
        for category in visionStore.categories {
            let count = visionStore.questions.filter { $0.categoryId == category.id }.count
            if count > 0 {
                testResults.append("✅ \(category.name): \(count) questions")
            } else {
                testResults.append("❌ \(category.name): No questions")
            }
        }
    }
    
    private func testAddAnswer() {
        testResults.append("ℹ️ Testing answer submission...")
        
        guard let firstCategory = visionStore.categories.first else {
            testResults.append("❌ No categories available")
            return
        }
        
        guard let firstQuestion = visionStore.questions.first(where: { $0.categoryId == firstCategory.id }) else {
            testResults.append("❌ No questions for \(firstCategory.name)")
            return
        }
        
        let testAnswerText = "This is a test answer for \(firstCategory.name)"
        
        visionStore.addAnswer(
            categoryId: firstCategory.id,
            questionText: firstQuestion.questionText,
            answerText: testAnswerText,
            timeframeYears: 5,
            confidence: 0.8
        )
        
        if visionStore.answers.contains(where: { $0.answerText == testAnswerText }) {
            testResults.append("✅ Answer added successfully")
            visionStore.markQuestionAnswered(firstQuestion.id)
            testResults.append("✅ Question marked as answered")
        } else {
            testResults.append("❌ Failed to add answer")
        }
    }
    
    private func testTodaysQuestions() {
        testResults.append("ℹ️ Testing today's questions...")
        
        let todaysQuestions = visionStore.getTodaysQuestions()
        
        if todaysQuestions.isEmpty {
            testResults.append("✅ No questions for today (all answered or skipped)")
        } else {
            testResults.append("✅ \(todaysQuestions.count) questions available today")
            for (index, question) in todaysQuestions.enumerated() {
                let categoryName = visionStore.categories.first(where: { $0.id == question.categoryId })?.name ?? "Unknown"
                testResults.append("  \(index + 1). \(categoryName) - \(question.timeframeYears)yr")
            }
        }
    }
    
    private func testGenerateFollowup() {
        testResults.append("ℹ️ Testing follow-up question generation...")
        
        // Find a category with at least one answer
        guard let categoryWithAnswer = visionStore.categories.first(where: { category in
            visionStore.answers.contains(where: { $0.categoryId == category.id })
        }) else {
            testResults.append("❌ Need at least one answer to generate follow-ups")
            testResults.append("ℹ️ Try 'Test 3: Add Sample Answer' first")
            return
        }
        
        let categoryAnswers = visionStore.answers.filter { $0.categoryId == categoryWithAnswer.id }
        
        Task {
            let newQuestions = await VisionAIService.shared.generateFollowUpQuestions(
                categoryId: categoryWithAnswer.id,
                categoryName: categoryWithAnswer.name,
                previousAnswers: categoryAnswers,
                timeframeYears: 5,
                count: 2
            )
            
            await MainActor.run {
                if !newQuestions.isEmpty {
                    visionStore.questions.append(contentsOf: newQuestions)
                    testResults.append("✅ Generated \(newQuestions.count) follow-up questions")
                    testResults.append("  Category: \(categoryWithAnswer.name)")
                } else {
                    testResults.append("❌ Failed to generate follow-up questions")
                }
            }
        }
    }
    
    private func clearAllData() {
        visionStore.categories.removeAll()
        visionStore.questions.removeAll()
        visionStore.answers.removeAll()
        visionStore.dailyLogs.removeAll()
        visionStore.statements.removeAll()
        visionStore.isFirstTime = true
        
        // Force re-initialization
        visionStore.categories = []
        
        testResults.append("⚠️ All data cleared")
        testResults.append("ℹ️ Restart the app to reinitialize")
    }
}

#Preview {
    VisionBoardTestingView()
}
