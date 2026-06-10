// Global Theme Management
(function() {
    'use strict';
    
    // Load saved theme on page load
    function loadTheme() {
        const savedTheme = localStorage.getItem('theme');
        if (savedTheme === 'dark') {
            document.body.classList.add('dark-mode');
            const darkModeToggle = document.getElementById('darkMode');
            if (darkModeToggle) {
                darkModeToggle.checked = true;
            }
        }
    }
    
    // Toggle theme function (can be called from anywhere)
    window.toggleTheme = function(enableDark) {
        if (enableDark) {
            document.body.classList.add('dark-mode');
            localStorage.setItem('theme', 'dark');
        } else {
            document.body.classList.remove('dark-mode');
            localStorage.setItem('theme', 'light');
        }
        
        // Dispatch theme change event for charts and other components
        document.dispatchEvent(new CustomEvent('themeChanged', {
            detail: { isDarkMode: enableDark }
        }));
    };
    
    // Initialize theme on DOM content loaded
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', loadTheme);
    } else {
        loadTheme();
    }
})(); 