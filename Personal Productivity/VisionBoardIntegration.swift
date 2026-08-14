import SwiftUI
import PhotosUI

// MARK: - Integration Example
// This shows how to integrate VisionBoardView into your existing app

// If you're using TabView (recommended for separation):
struct MainAppView: View {
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var taskStore = TaskStore(settings: AppSettingsStore())
    @StateObject private var visionStore = VisionBoardStore()
    @State private var selectedTab: AppTab = .calendar
    
    enum AppTab {
        case calendar
        case vision
        case dashboard
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Calendar Tab
            CalendarView()
                .environmentObject(taskStore)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(AppTab.calendar)
            
            // Vision Board Tab (NEW)
            VisionBoardView(visionStore: visionStore)
                .environmentObject(settings)
                .tabItem {
                    Label("Vision", systemImage: "sparkles")
                }
                .tag(AppTab.vision)
            
            // Note: This is example code - DashboardView requires MainTabView.Tab binding
            // In actual integration, use your existing MainTabView instead
        }
        .tint(Color(red: 1.0, green: 0.23, blue: 0.19)) // Your app's red color
    }
}

// MARK: - Alternative: NavigationStack Integration
// If you prefer a navigation-based approach:

struct MainAppViewWithNavigation: View {
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var taskStore = TaskStore(settings: AppSettingsStore())
    @StateObject private var visionStore = VisionBoardStore()
    @State private var selectedTab: String = "home"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ZStack {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Personal Productivity")
                                .font(.title2.weight(.bold))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        ScrollView {
                            VStack(spacing: 12) {
                                NavigationLink(destination: CalendarView().environmentObject(taskStore)) {
                                    MainMenuCard(
                                        icon: "📅",
                                        title: "Calendar",
                                        description: "View and manage your tasks"
                                    )
                                }
                                
                                NavigationLink(destination: VisionBoardView(visionStore: visionStore).environmentObject(settings)) {
                                    MainMenuCard(
                                        icon: "✨",
                                        title: "Vision Board",
                                        description: "Build your future vision"
                                    )
                                }
                                
                                // Note: DashboardView requires MainTabView.Tab binding
                                // Use your existing MainTabView for full navigation
                            }
                            .padding(16)
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag("home")
        }
    }
}

// MARK: - Helper Card for Menu
private struct MainMenuCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(icon)
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Environment Setup
// Add this to your app's main struct (Personal_ProductivityApp.swift)

/*
@main
struct Personal_ProductivityApp: App {
    @StateObject private var taskStore = TaskStore()
    @StateObject private var visionBoardStore = VisionBoardStore() // ADD THIS
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(taskStore)
                .environmentObject(visionBoardStore) // ADD THIS
        }
    }
}
*/

// MARK: - Advanced: Linking Calendar and Vision
// If you want to create tasks from vision goals:

extension VisionAnswer {
    /// Creates a FocusTask from a vision answer
    func createFocusTask(from category: VisionCategory) -> FocusTask? {
        // This is a template - adjust based on your FocusTask structure
        
        let _ = "\(category.emoji) \(category.name): \(answerText.prefix(30))..."
        let _ = "Vision Goal - \(timeframeYears) year goal: \(answerText)"
        
        // You would create a FocusTask here and return it
        // This allows users to convert vision goals into actionable tasks
        
        return nil // Placeholder
    }
}

// Usage example:
/*
// In a view, user can convert vision answer to task:
if let task = answer.createFocusTask(from: category) {
    taskStore.addTask(task)
}
*/

#Preview {
    MainAppView()
}
