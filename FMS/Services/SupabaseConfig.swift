import Foundation

enum SupabaseConfig {
    // Paste your Supabase project URL here
    static let url = URL(string: "https://djgxuemumbylxwuklfhk.supabase.co")!
    
    // Paste your Supabase Anon key here
    static let key = "sb_publishable_mTQn6lAZIAPlJC2OAv6rtQ_D4-vFqI6"
    
    /// Checks if credentials are valid and not placeholders.
    /// By default, this will be false until you replace the values above.
    static var isConfigured: Bool {
        !key.isEmpty && 
        !key.contains("placeholder") && 
        url.absoluteString.contains("supabase.co") && 
        !url.absoluteString.contains("your-supabase-project")
    }
}
