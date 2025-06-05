# AI Usage Guide for AppMCP

This guide helps AI assistants (like Claude) understand how to properly use AppMCP tools and resources.

## 🔍 Finding Applications

### ❌ WRONG: Don't use resolve_app to list all apps
```json
// This won't work - resolve_app doesn't support wildcards
{
  "tool": "resolve_app",
  "arguments": {
    "process_name": ".*"  // ❌ No regex/wildcards allowed
  }
}
```

### ✅ CORRECT: Use running_applications resource
```json
// Get ALL running applications
{
  "method": "resources/read",
  "params": {
    "uri": "appmcp://resources/running_applications"
  }
}
```

## 📋 Common Tasks

### 1. List all available apps
**Use:** `running_applications` resource
**Returns:** Array of all running apps with names, bundle IDs, PIDs

### 2. Find a specific app
**Use:** `resolve_app` tool with exact name/bundle ID
**Example:**
```json
{
  "tool": "resolve_app",
  "arguments": {
    "bundle_id": "com.apple.Safari"  // Exact match only
  }
}
```

### 3. Get windows for an app
**First:** Use `resolve_app` to get app_handle
**Then:** Use `list_windows` resource with the handle

## 🎯 Tool vs Resource

### Tools (Actions)
- **resolve_app**: Find ONE specific app → get app_handle
- **resolve_window**: Find ONE window in app → get window_handle  
- **mouse_click**: Click at coordinates → click buttons/links
- **type_text**: Type into focused field → enter text/search terms
- **perform_gesture**: Swipe/pinch/rotate → scroll/zoom/navigate
- **wait**: Pause execution → let UI update after actions

### Resources (Information)
- **running_applications**: List ALL running apps → see what's available
- **accessible_applications**: List controllable apps → see what you can interact with
- **installed_applications**: List installed apps → see what exists on system
- **list_windows**: List windows of specific app → see available windows

## 🔄 Typical Workflow

### Example: Automate Weather app
```
1. running_applications → see "天気 (com.apple.weather)"
2. resolve_app {bundle_id: "com.apple.weather"} → get "ah_1234"  
3. resolve_window {app_handle: "ah_1234", index: 0} → get "wh_5678"
4. mouse_click {window_handle: "wh_5678", x: 100, y: 50} → click search field
5. wait {duration_ms: 500} → let UI update
6. type_text {window_handle: "wh_5678", text: "Tokyo"} → enter search
7. wait {duration_ms: 1000} → let search complete
8. mouse_click {window_handle: "wh_5678", x: 200, y: 100} → click result
```

## 💡 Best Practices

1. **Start with running_applications** to see what's available
2. **Use exact matches** - Tools need exact names/bundle IDs, not patterns  
3. **Always wait after actions** - Let UI update before next step
4. **Get handles first** - Need app_handle before window_handle before actions
5. **Check accessible_applications** - See which apps you can actually control

## 🚫 Common Mistakes

1. **Using regex/wildcards** - AppMCP tools use exact matching
2. **Confusing tools and resources** - Tools perform actions, resources get information
3. **Not checking if app is running** - Always verify with `running_applications` first