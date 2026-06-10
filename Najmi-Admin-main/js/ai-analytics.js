// AI Analytics functionality with Gemini AI integration
const GEMINI_API_KEY = 'AIzaSyCZ6y8DEHcZQfdjPHEN0pzX9n5KpowZcm0';
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

let businessData = {
    products: [],
    brands: [],
    categories: [],
    featuredProducts: [],
    featuredBrands: [],
    imageSlides: []
};

// Wait for Supabase to be initialized
function waitForSupabase() {
    return new Promise((resolve) => {
        const checkSupabase = () => {
            if (window.supabaseClient) {
                resolve(window.supabaseClient);
            } else {
                setTimeout(checkSupabase, 100);
            }
        };
        checkSupabase();
    });
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', async function() {
    console.log('AI Analytics page loaded');
    
    // Wait for Supabase to be ready
    const supabaseClient = await waitForSupabase();
    
    // Check authentication
    const { data: { user } } = await supabaseClient.auth.getUser();
    if (!user) {
        console.log('User not authenticated, redirecting to login');
        window.location.href = '../index.html';
        return;
    }

    // Set user info
    document.getElementById('userName').textContent = user.user_metadata?.full_name || user.email || 'Admin';
    document.getElementById('userEmail').textContent = user.email;

    // Load business data
    await loadBusinessData();
    
    // Initialize AI chat
    initializeAIChat();
    
    // Generate initial AI insights
    await generateInitialInsights();
    
    // Generate initial recommendations
    await generateRecommendations();
});

// Load all business data for AI analysis
async function loadBusinessData() {
    try {
        const supabaseClient = await waitForSupabase();
        
        // Load all data in parallel
        const [productsResult, brandsResult, categoriesResult, featuredProductsResult, featuredBrandsResult, imageSlidesResult] = await Promise.all([
            supabaseClient.from('products').select('*').limit(100),
            supabaseClient.from('brands').select('*'),
            supabaseClient.from('categories').select('*').limit(50),
            supabaseClient.from('featured_products').select('*').limit(20),
            supabaseClient.from('featured_brands').select('*').limit(20),
            supabaseClient.from('image_slides').select('*').limit(10)
        ]);

                businessData.products = productsResult.data || [];
        businessData.brands = brandsResult.data || [];
        businessData.categories = categoriesResult.data || [];
        businessData.featuredProducts = featuredProductsResult.data || [];
        businessData.featuredBrands = featuredBrandsResult.data || [];
        businessData.imageSlides = imageSlidesResult.data || [];
        
        console.log('Business data loaded:', businessData);
        
        // Update metrics
        await updateMetrics();
        
        // Create charts
        await createCharts();
    } catch (error) {
        console.error('Error loading business data:', error);
    }
}

// Initialize AI chat functionality
function initializeAIChat() {
    const messageInput = document.getElementById('aiMessageInput');
    const sendButton = document.getElementById('sendAiMessage');
    const searchInput = document.getElementById('aiSearchInput');

    // Send message on button click
    sendButton.addEventListener('click', sendAIMessage);
    
    // Send message on Enter key
    messageInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            sendAIMessage();
        }
    });

    // Search input functionality
    searchInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            const query = this.value.trim();
            if (query) {
                addUserMessage(query);
                processAIQuery(query);
                this.value = '';
            }
        }
    });
}

// Send AI message
async function sendAIMessage() {
    const messageInput = document.getElementById('aiMessageInput');
    const message = messageInput.value.trim();
    
    if (!message) return;
    
    messageInput.value = '';
    addUserMessage(message);
    await processAIQuery(message);
}

// Add user message to chat
function addUserMessage(message) {
    const chatMessages = document.getElementById('aiChatMessages');
    const userMessage = document.createElement('div');
    userMessage.className = 'user-message';
    userMessage.innerHTML = `
        <div class="message-content">
            <p>${message}</p>
        </div>
        <div class="message-avatar">
            <i class="ri-user-line"></i>
        </div>
    `;
    chatMessages.appendChild(userMessage);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Add AI response to chat
function addAIResponse(response) {
    const chatMessages = document.getElementById('aiChatMessages');
    const aiMessage = document.createElement('div');
    aiMessage.className = 'ai-message';
    aiMessage.innerHTML = `
        <div class="message-avatar">
            <i class="ri-robot-line"></i>
        </div>
        <div class="message-content">
            <p>${response}</p>
        </div>
    `;
    chatMessages.appendChild(aiMessage);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Process AI query using Gemini
async function processAIQuery(query) {
    try {
        // Show typing indicator
        const chatMessages = document.getElementById('aiChatMessages');
        const typingIndicator = document.createElement('div');
        typingIndicator.className = 'ai-message typing';
        typingIndicator.innerHTML = `
            <div class="message-avatar">
                <i class="ri-robot-line"></i>
            </div>
            <div class="message-content">
                <div class="typing-dots">
                    <span></span>
                    <span></span>
                    <span></span>
                </div>
            </div>
        `;
        chatMessages.appendChild(typingIndicator);
        chatMessages.scrollTop = chatMessages.scrollHeight;

        // Prepare context for AI
        const context = prepareBusinessContext();
        const prompt = `You are an AI business analyst for a construction materials company. Based on the following business data, answer the user's question: "${query}"

Business Data:
${context}

Please provide a helpful, actionable response based on the data. If the data is insufficient, suggest what additional information would be helpful.`;

        // Call Gemini API
        const response = await callGeminiAPI(prompt);
        
        // Remove typing indicator
        typingIndicator.remove();
        
        // Add AI response
        addAIResponse(response);
        
    } catch (error) {
        console.error('Error processing AI query:', error);
        addAIResponse('Sorry, I encountered an error while processing your request. Please try again.');
    }
}

// Prepare business context for AI
function prepareBusinessContext() {
    const context = [];
    
    // Products summary
    if (businessData.products.length > 0) {
        const totalProducts = businessData.products.length;
        const activeProducts = businessData.products.filter(p => p.is_active !== false).length;
        const categories = [...new Set(businessData.products.map(p => p.category).filter(Boolean))];
        
        context.push(`Products: ${totalProducts} total, ${activeProducts} active, across ${categories.length} categories: ${categories.join(', ')}`);
    }
    
    // Brands summary
    if (businessData.brands.length > 0) {
        const totalBrands = businessData.brands.length;
        const activeBrands = businessData.brands.filter(b => b.is_active !== false).length;
        context.push(`Brands: ${totalBrands} total, ${activeBrands} active`);
    }
    
    // Featured items
    if (businessData.featuredProducts.length > 0) {
        context.push(`Featured Products: ${businessData.featuredProducts.length} items`);
    }
    
    if (businessData.featuredBrands.length > 0) {
        context.push(`Featured Brands: ${businessData.featuredBrands.length} items`);
    }
    
    // Image slides
    if (businessData.imageSlides.length > 0) {
        context.push(`Promotional Slides: ${businessData.imageSlides.length} active slides`);
    }
    
    return context.join('\n');
}

// Call Gemini API
async function callGeminiAPI(prompt) {
    try {
        const response = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                contents: [{
                    parts: [{
                        text: prompt
                    }]
                }]
            })
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error('Gemini API Error:', response.status, errorText);
            throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
        }

        const data = await response.json();
        
        if (!data.candidates || !data.candidates[0] || !data.candidates[0].content) {
            console.error('Unexpected API response:', data);
            throw new Error('Invalid API response format');
        }
        
        return data.candidates[0].content.parts[0].text;
    } catch (error) {
        console.error('Gemini API call failed:', error);
        
        // Fallback to mock responses for demo purposes
        if (error.message.includes('404') || error.message.includes('CORS') || error.message.includes('429')) {
            return generateMockResponse(prompt);
        }
        
        throw error;
    }
}

// Generate mock responses for demo purposes when API is unavailable
function generateMockResponse(prompt) {
    const lowerPrompt = prompt.toLowerCase();
    
    if (lowerPrompt.includes('top performing') || lowerPrompt.includes('products')) {
        return "Your top categories are building materials and plumbing supplies. Consider featuring best-selling items for better visibility.";
    }
    
    if (lowerPrompt.includes('business performance') || lowerPrompt.includes('monthly')) {
        return "Good diversity across categories. Focus on inventory management and seasonal trends for better performance.";
    }
    
    if (lowerPrompt.includes('growth') || lowerPrompt.includes('recommendations')) {
        return "Key growth areas: 1) Expand featured products, 2) Better inventory tracking, 3) Add customer reviews, 4) Optimize categories.";
    }
    
    if (lowerPrompt.includes('inventory')) {
        return "Implement stock alerts and focus on profitable product lines for optimal inventory management.";
    }
    
    return "Your construction materials business shows good organization. For detailed analysis, try again later.";
}

// Generate initial AI insights
async function generateInitialInsights() {
    try {
        // Use mock responses to avoid API quota issues
        generateMockInsights();
    } catch (error) {
        console.error('Error generating insights:', error);
    }
}

// Generate mock insights without API calls
function generateMockInsights() {
    // Sales Trends Insight
    document.getElementById('salesTrendsInsight').innerHTML = `
        <div class="insight-text">
            <p>Good category diversity. Focus on inventory management and seasonal trends for better performance.</p>
        </div>
    `;
    
    // Product Performance Insight
    document.getElementById('productPerformanceInsight').innerHTML = `
        <div class="insight-text">
            <p>Strong catalog diversity. Feature best-performing categories and optimize descriptions for better engagement.</p>
        </div>
    `;
    
    // Brand Analysis Insight
    document.getElementById('brandAnalysisInsight').innerHTML = `
        <div class="insight-text">
            <p>Good brand portfolio coverage. Strengthen relationships with top brands and expand partnerships.</p>
        </div>
    `;
    
    // Growth Opportunities Insight
    document.getElementById('growthOpportunitiesInsight').innerHTML = `
        <div class="insight-text">
            <p>Key opportunities: Expand featured products, better inventory management, leverage seasonal trends, and digital marketing.</p>
        </div>
    `;
}

// Generate sales trends insight
async function generateSalesTrendsInsight() {
    const context = prepareBusinessContext();
    const prompt = `Analyze the sales trends for this construction materials business based on the following data:

${context}

Provide a brief analysis (2-3 sentences) of sales trends and performance indicators. Focus on actionable insights.`;

    try {
        const insight = await callGeminiAPI(prompt);
        document.getElementById('salesTrendsInsight').innerHTML = `
            <div class="insight-text">
                <p>${insight}</p>
            </div>
        `;
    } catch (error) {
        console.error('Error generating sales trends insight:', error);
        document.getElementById('salesTrendsInsight').innerHTML = `
            <div class="insight-text">
                <p>Good category diversity. Focus on inventory management and seasonal trends for better performance.</p>
            </div>
        `;
    }
}

// Generate product performance insight
async function generateProductPerformanceInsight() {
    const context = prepareBusinessContext();
    const prompt = `Analyze the product performance for this construction materials business based on the following data:

${context}

Provide a brief analysis (2-3 sentences) of product performance, top categories, and recommendations for improvement.`;

    try {
        const insight = await callGeminiAPI(prompt);
        document.getElementById('productPerformanceInsight').innerHTML = `
            <div class="insight-text">
                <p>${insight}</p>
            </div>
        `;
    } catch (error) {
        console.error('Error generating product performance insight:', error);
        document.getElementById('productPerformanceInsight').innerHTML = `
            <div class="insight-text">
                <p>Strong catalog diversity. Feature best-performing categories and optimize descriptions for better engagement.</p>
            </div>
        `;
    }
}

// Generate brand analysis insight
async function generateBrandAnalysisInsight() {
    const context = prepareBusinessContext();
    const prompt = `Analyze the brand performance for this construction materials business based on the following data:

${context}

Provide a brief analysis (2-3 sentences) of brand performance, brand diversity, and recommendations for brand strategy.`;

    try {
        const insight = await callGeminiAPI(prompt);
        document.getElementById('brandAnalysisInsight').innerHTML = `
            <div class="insight-text">
                <p>${insight}</p>
            </div>
        `;
    } catch (error) {
        console.error('Error generating brand analysis insight:', error);
        document.getElementById('brandAnalysisInsight').innerHTML = `
            <div class="insight-text">
                <p>Good brand portfolio coverage. Strengthen relationships with top brands and expand partnerships.</p>
            </div>
        `;
    }
}

// Generate growth opportunities insight
async function generateGrowthOpportunitiesInsight() {
    const context = prepareBusinessContext();
    const prompt = `Identify growth opportunities for this construction materials business based on the following data:

${context}

Provide a brief analysis (2-3 sentences) of potential growth opportunities, market gaps, and strategic recommendations.`;

    try {
        const insight = await callGeminiAPI(prompt);
        document.getElementById('growthOpportunitiesInsight').innerHTML = `
            <div class="insight-text">
                <p>${insight}</p>
            </div>
        `;
    } catch (error) {
        console.error('Error generating growth opportunities insight:', error);
        document.getElementById('growthOpportunitiesInsight').innerHTML = `
            <div class="insight-text">
                <p>Key opportunities: Expand featured products, better inventory management, leverage seasonal trends, and digital marketing.</p>
            </div>
        `;
    }
}

// Generate AI recommendations
async function generateRecommendations() {
    const context = prepareBusinessContext();
    const prompt = `Based on the following business data, provide 3-5 specific, actionable recommendations for this construction materials business:

${context}

Format each recommendation as:
- Title: Brief recommendation title
- Description: 1-2 sentence explanation
- Priority: High/Medium/Low

Focus on practical, implementable suggestions.`;

    try {
        // Use default recommendations to avoid API quota issues
        displayDefaultRecommendations();
    } catch (error) {
        console.error('Error generating recommendations:', error);
        // Display default recommendations when AI is unavailable
        displayDefaultRecommendations();
    }
}

// Display default recommendations when AI is unavailable
function displayDefaultRecommendations() {
    const recommendationsContainer = document.getElementById('aiRecommendations');
    const defaultRecommendations = [
        {
            title: "Optimize Product Categories",
            description: "Consider expanding your top-performing categories to increase revenue potential.",
            priority: "high"
        },
        {
            title: "Inventory Management",
            description: "Review stock levels for fast-moving products to avoid stockouts.",
            priority: "medium"
        },
        {
            title: "Featured Products",
            description: "Update your featured products section with trending items.",
            priority: "low"
        },
        {
            title: "Brand Partnerships",
            description: "Strengthen relationships with top-performing brands for better margins.",
            priority: "medium"
        },
        {
            title: "Digital Marketing",
            description: "Implement SEO strategies to improve online visibility and attract new customers.",
            priority: "high"
        }
    ];
    
    recommendationsContainer.innerHTML = defaultRecommendations.map(rec => `
        <div class="recommendation-item">
            <div class="recommendation-icon">
                <i class="ri-lightbulb-line"></i>
            </div>
            <div class="recommendation-content">
                <h4>${rec.title}</h4>
                <p>${rec.description}</p>
                <span class="recommendation-priority ${rec.priority}">${rec.priority.charAt(0).toUpperCase() + rec.priority.slice(1)} Priority</span>
            </div>
        </div>
    `).join('');
}

// Update business metrics
async function updateMetrics() {
    try {
        const supabaseClient = await waitForSupabase();
        
        // Get actual counts from database
        const [productsCount, brandsCount, categoriesCount, featuredProductsCount, featuredBrandsCount, imageSlidesCount] = await Promise.all([
            supabaseClient.from('products').select('*', { count: 'exact', head: true }),
            supabaseClient.from('brands').select('*', { count: 'exact', head: true }),
            supabaseClient.from('categories').select('*', { count: 'exact', head: true }),
            supabaseClient.from('featured_products').select('*', { count: 'exact', head: true }),
            supabaseClient.from('featured_brands').select('*', { count: 'exact', head: true }),
            supabaseClient.from('image_slides').select('*', { count: 'exact', head: true })
        ]);
        
        // Update the metrics with actual counts
        document.getElementById('totalProducts').textContent = productsCount.count || 0;
        document.getElementById('totalBrands').textContent = brandsCount.count || 0;
        document.getElementById('totalCategories').textContent = categoriesCount.count || 0;
        
        // Calculate total featured items
        const featuredItems = (featuredProductsCount.count || 0) + 
                             (featuredBrandsCount.count || 0) + 
                             (imageSlidesCount.count || 0);
        document.getElementById('featuredItems').textContent = featuredItems;
        
        console.log('Metrics updated with actual counts:', {
            products: productsCount.count,
            brands: brandsCount.count,
            categories: categoriesCount.count,
            featuredItems: featuredItems
        });
        
    } catch (error) {
        console.error('Error updating metrics:', error);
        // Fallback to array lengths if count queries fail
        document.getElementById('totalProducts').textContent = businessData.products.length;
        document.getElementById('totalBrands').textContent = businessData.brands.length;
        document.getElementById('totalCategories').textContent = businessData.categories.length;
        
        const featuredItems = (businessData.featuredProducts?.length || 0) + 
                             (businessData.featuredBrands?.length || 0) + 
                             (businessData.imageSlides?.length || 0);
        document.getElementById('featuredItems').textContent = featuredItems;
    }
}

// Create charts
async function createCharts() {
    await createCategoryChart();
    await createBrandChart();
    await createPricingChart();
    await createStockChart();
}

// Category Chart
async function createCategoryChart() {
    const ctx = document.getElementById('categoryChart').getContext('2d');
    
    try {
        const supabaseClient = await waitForSupabase();
        
        // Fetch all products to get accurate category distribution
        const { data: allProducts, error } = await supabaseClient
            .from('products')
            .select('category');
            
        if (error) throw error;
        
        // Count products by category
        const categoryCounts = {};
        (allProducts || []).forEach(product => {
            const category = product.category || 'Uncategorized';
            categoryCounts[category] = (categoryCounts[category] || 0) + 1;
        });
        
        const labels = Object.keys(categoryCounts);
        const data = Object.values(categoryCounts);
        
        new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: [
                        '#3B82F6',
                        '#10B981',
                        '#F59E0B',
                        '#EF4444',
                        '#8B5CF6',
                        '#06B6D4',
                        '#84CC16',
                        '#F97316'
                    ],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 20,
                            usePointStyle: true
                        }
                    }
                }
            }
        });
        
    } catch (error) {
        console.error('Error creating category chart:', error);
        // Fallback to limited data
        const categoryCounts = {};
        businessData.products.forEach(product => {
            const category = product.category || 'Uncategorized';
            categoryCounts[category] = (categoryCounts[category] || 0) + 1;
        });
        
        const labels = Object.keys(categoryCounts);
        const data = Object.values(categoryCounts);
        
        new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: [
                        '#3B82F6',
                        '#10B981',
                        '#F59E0B',
                        '#EF4444',
                        '#8B5CF6',
                        '#06B6D4',
                        '#84CC16',
                        '#F97316'
                    ],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 20,
                            usePointStyle: true
                        }
                    }
                }
            }
        });
    }
}

// Brand Chart
async function createBrandChart() {
    const ctx = document.getElementById('brandChart').getContext('2d');
    
    try {
        const supabaseClient = await waitForSupabase();
        
        // Fetch all products to get accurate brand distribution
        const { data: allProducts, error } = await supabaseClient
            .from('products')
            .select('brand_name');
            
        if (error) throw error;
        
        // Count products by brand
        const brandCounts = {};
        (allProducts || []).forEach(product => {
            const brand = product.brand_name || 'Unknown Brand';
            brandCounts[brand] = (brandCounts[brand] || 0) + 1;
        });
        
        // Get top 10 brands
        const sortedBrands = Object.entries(brandCounts)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 10);
        
        const labels = sortedBrands.map(([brand]) => brand);
        const data = sortedBrands.map(([, count]) => count);
        
        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Products',
                    data: data,
                    backgroundColor: '#3B82F6',
                    borderRadius: 6,
                    borderSkipped: false
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: 'rgba(0, 0, 0, 0.1)'
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        }
                    }
                }
            }
        });
        
    } catch (error) {
        console.error('Error creating brand chart:', error);
        // Fallback to limited data
        const brandCounts = {};
        businessData.products.forEach(product => {
            const brand = product.brand_name || 'Unknown Brand';
            brandCounts[brand] = (brandCounts[brand] || 0) + 1;
        });
        
        const sortedBrands = Object.entries(brandCounts)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 10);
        
        const labels = sortedBrands.map(([brand]) => brand);
        const data = sortedBrands.map(([, count]) => count);
        
        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Products',
                    data: data,
                    backgroundColor: '#3B82F6',
                    borderRadius: 6,
                    borderSkipped: false
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: 'rgba(0, 0, 0, 0.1)'
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        }
                    }
                }
            }
        });
    }
}

// Pricing Chart
async function createPricingChart() {
    const ctx = document.getElementById('pricingChart').getContext('2d');
    
    try {
        const supabaseClient = await waitForSupabase();
        
        // Fetch all products to get accurate pricing distribution
        const { data: allProducts, error } = await supabaseClient
            .from('products')
            .select('final_price');
            
        if (error) throw error;
        
        // Analyze pricing ranges
        const priceRanges = {
            'Under ₹100': 0,
            '₹100-500': 0,
            '₹500-1000': 0,
            '₹1000-5000': 0,
            'Above ₹5000': 0
        };
        
        (allProducts || []).forEach(product => {
            const price = parseFloat(product.final_price) || 0;
            if (price < 100) priceRanges['Under ₹100']++;
            else if (price < 500) priceRanges['₹100-500']++;
            else if (price < 1000) priceRanges['₹500-1000']++;
            else if (price < 5000) priceRanges['₹1000-5000']++;
            else priceRanges['Above ₹5000']++;
        });
        
        new Chart(ctx, {
            type: 'pie',
            data: {
                labels: Object.keys(priceRanges),
                datasets: [{
                    data: Object.values(priceRanges),
                    backgroundColor: [
                        '#10B981',
                        '#3B82F6',
                        '#F59E0B',
                        '#EF4444',
                        '#8B5CF6'
                    ],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 20,
                            usePointStyle: true
                        }
                    }
                }
            }
        });
        
    } catch (error) {
        console.error('Error creating pricing chart:', error);
        // Fallback to limited data
        const priceRanges = {
            'Under ₹100': 0,
            '₹100-500': 0,
            '₹500-1000': 0,
            '₹1000-5000': 0,
            'Above ₹5000': 0
        };
        
        businessData.products.forEach(product => {
            const price = parseFloat(product.final_price) || 0;
            if (price < 100) priceRanges['Under ₹100']++;
            else if (price < 500) priceRanges['₹100-500']++;
            else if (price < 1000) priceRanges['₹500-1000']++;
            else if (price < 5000) priceRanges['₹1000-5000']++;
            else priceRanges['Above ₹5000']++;
        });
        
        new Chart(ctx, {
            type: 'pie',
            data: {
                labels: Object.keys(priceRanges),
                datasets: [{
                    data: Object.values(priceRanges),
                    backgroundColor: [
                        '#10B981',
                        '#3B82F6',
                        '#F59E0B',
                        '#EF4444',
                        '#8B5CF6'
                    ],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 20,
                            usePointStyle: true
                        }
                    }
                }
            }
        });
    }
}

// Stock Chart
async function createStockChart() {
    const ctx = document.getElementById('stockChart').getContext('2d');
    
    try {
        const supabaseClient = await waitForSupabase();
        
        // Fetch all products to get accurate stock status distribution
        const { data: allProducts, error } = await supabaseClient
            .from('products')
            .select('stock_status');
            
        if (error) throw error;
        
        // Count stock status
        const stockStatus = {
            'In Stock': 0,
            'Low Stock': 0,
            'Out of Stock': 0
        };
        
        (allProducts || []).forEach(product => {
            const status = product.stock_status || 'In Stock';
            if (stockStatus.hasOwnProperty(status)) {
                stockStatus[status]++;
            } else {
                stockStatus['In Stock']++;
            }
        });
        
        new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: Object.keys(stockStatus),
                datasets: [{
                    data: Object.values(stockStatus),
                    backgroundColor: [
                        '#10B981',
                        '#F59E0B',
                        '#EF4444'
                    ],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 20,
                            usePointStyle: true
                        }
                    }
                }
            }
        });
        
    } catch (error) {
        console.error('Error creating stock chart:', error);
        // Fallback to limited data
        const stockStatus = {
            'In Stock': 0,
            'Low Stock': 0,
            'Out of Stock': 0
        };
        
        businessData.products.forEach(product => {
            const status = product.stock_status || 'In Stock';
            if (stockStatus.hasOwnProperty(status)) {
                stockStatus[status]++;
            } else {
                stockStatus['In Stock']++;
            }
        });
        
        new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: Object.keys(stockStatus),
                datasets: [{
                    data: Object.values(stockStatus),
                    backgroundColor: [
                        '#10B981',
                        '#F59E0B',
                        '#EF4444'
                    ],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 20,
                            usePointStyle: true
                        }
                    }
                }
            }
        });
    }
}

// Display AI recommendations
function displayRecommendations(recommendationsText) {
    const recommendationsContainer = document.getElementById('aiRecommendations');
    
    // Parse recommendations (simple parsing for demo)
    const lines = recommendationsText.split('\n').filter(line => line.trim());
    let recommendations = [];
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.startsWith('-') || line.startsWith('•')) {
            const title = line.replace(/^[-•]\s*/, '');
            let description = '';
            let priority = 'medium';
            
            // Look for description and priority in next lines
            if (i + 1 < lines.length && !lines[i + 1].startsWith('-') && !lines[i + 1].startsWith('•')) {
                description = lines[i + 1].trim();
                i++;
            }
            
            if (i + 1 < lines.length && lines[i + 1].toLowerCase().includes('priority')) {
                const priorityLine = lines[i + 1].toLowerCase();
                if (priorityLine.includes('high')) priority = 'high';
                else if (priorityLine.includes('low')) priority = 'low';
                i++;
            }
            
            recommendations.push({ title, description, priority });
        }
    }
    
    // Display recommendations
    if (recommendations.length > 0) {
        recommendationsContainer.innerHTML = recommendations.map(rec => `
            <div class="recommendation-item">
                <div class="recommendation-icon">
                    <i class="ri-lightbulb-line"></i>
                </div>
                <div class="recommendation-content">
                    <h4>${rec.title}</h4>
                    <p>${rec.description || 'AI-generated recommendation for business improvement.'}</p>
                    <span class="recommendation-priority ${rec.priority}">${rec.priority.charAt(0).toUpperCase() + rec.priority.slice(1)} Priority</span>
                </div>
            </div>
        `).join('');
    }
}

// Generate AI monthly report
async function generateAIMonthlyReport() {
    try {
        const context = prepareBusinessContext();
        const prompt = `Generate a comprehensive monthly business report for this construction materials company based on the following data:

${context}

Include:
1. Executive Summary
2. Key Performance Indicators
3. Product Analysis
4. Brand Performance
5. Growth Opportunities
6. Recommendations for next month

Format as a professional business report with clear sections and actionable insights.`;

        const report = await callGeminiAPI(prompt);
        
        // Create report card
        const reportsGrid = document.getElementById('aiReportsGrid');
        const reportCard = document.createElement('div');
        reportCard.className = 'report-card';
        reportCard.innerHTML = `
            <div class="report-header">
                <i class="ri-file-chart-line"></i>
                <h3>Monthly Business Report</h3>
                <span class="report-date">Generated: ${new Date().toLocaleDateString()}</span>
            </div>
            <div class="report-content">
                <div class="report-text">
                    ${report.split('\n').map(line => `<p>${line}</p>`).join('')}
                </div>
                <div class="report-actions">
                    <button class="btn-secondary" onclick="downloadReport('${report.replace(/'/g, "\\'")}')">
                        <i class="ri-download-line"></i>
                        Download Report
                    </button>
                </div>
            </div>
        `;
        
        reportsGrid.insertBefore(reportCard, reportsGrid.firstChild);
        
    } catch (error) {
        console.error('Error generating monthly report:', error);
        alert('Error generating report. Please try again.');
    }
}

// Download report
function downloadReport(reportText) {
    const blob = new Blob([reportText], { type: 'text/plain' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `business-report-${new Date().toISOString().split('T')[0]}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
}

// Refresh recommendations
async function refreshRecommendations() {
    const button = event.target.closest('button');
    const originalText = button.innerHTML;
    button.innerHTML = '<i class="ri-loader-4-line"></i> Refreshing...';
    button.disabled = true;
    
    try {
        await generateRecommendations();
    } finally {
        button.innerHTML = originalText;
        button.disabled = false;
    }
}

// Ask quick question
function askQuickQuestion(question) {
    const messageInput = document.getElementById('aiMessageInput');
    messageInput.value = question;
    sendAIMessage();
}

// Update AI status
function updateAIStatus(status, message) {
    const statusElement = document.getElementById('aiStatus');
    statusElement.innerHTML = `
        <i class="ri-robot-line"></i>
        ${message}
    `;
    statusElement.className = `ai-indicator ${status}`;
}

// Try AI generation when user clicks the button
async function tryAIGeneration() {
    const statusElement = document.getElementById('aiStatus');
    statusElement.innerHTML = '<i class="ri-loader-4-line"></i> Generating AI Insights...';
    statusElement.className = 'ai-indicator loading';
    
    try {
        // Try to generate one insight to test API availability
        const context = prepareBusinessContext();
        const prompt = `Analyze the sales trends for this construction materials business based on the following data:

${context}

Provide a brief analysis (2-3 sentences) of sales trends and performance indicators. Focus on actionable insights.`;

        const insight = await callGeminiAPI(prompt);
        
        // If successful, update the sales trends insight
        document.getElementById('salesTrendsInsight').innerHTML = `
            <div class="insight-text">
                <p>${insight}</p>
            </div>
        `;
        
        statusElement.innerHTML = '<i class="ri-robot-line"></i> AI Active';
        statusElement.className = 'ai-indicator active';
        
        // Show success message
        showNotification('AI generation successful! You can now use AI features.', 'success');
        
    } catch (error) {
        console.error('AI generation failed:', error);
        
        if (error.message.includes('429')) {
            statusElement.innerHTML = '<i class="ri-error-warning-line"></i> API Quota Exceeded';
            statusElement.className = 'ai-indicator error';
            showNotification('API quota exceeded. Free tier allows 50 requests per day. Try again tomorrow or upgrade your plan.', 'error');
        } else {
            statusElement.innerHTML = '<i class="ri-error-warning-line"></i> AI Unavailable';
            statusElement.className = 'ai-indicator error';
            showNotification('AI service temporarily unavailable. Using fallback insights.', 'warning');
        }
    }
}

// Show notification
function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <div class="notification-content">
            <i class="ri-${type === 'success' ? 'check-line' : type === 'error' ? 'error-warning-line' : 'information-line'}"></i>
            <span>${message}</span>
        </div>
    `;
    
    // Add to page
    document.body.appendChild(notification);
    
    // Show notification
    setTimeout(() => notification.classList.add('show'), 100);
    
    // Remove after 5 seconds
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => notification.remove(), 300);
    }, 5000);
}
