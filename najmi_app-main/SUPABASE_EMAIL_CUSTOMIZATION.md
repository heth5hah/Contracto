# Supabase Email Template Customization Guide for Contracto

## Overview
This guide explains how to customize Supabase email templates to match Contracto's branding and provide a personalized experience for users.

## Current Configuration
- **Supabase URL**: `https://qboyfdwwrimditugblwo.supabase.co`
- **Redirect URL**: `https://contractobuild.com/emailverified`
- **App Name**: Contracto

## Steps to Customize Email Templates

### 1. Access Supabase Dashboard
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project: `qboyfdwwrimditugblwo`
3. Navigate to **Authentication** → **Email Templates**

### 2. Customize Signup Confirmation Email

#### Template Variables Available:
- `{{ .SiteURL }}` - Your site URL
- `{{ .ConfirmationURL }}` - Confirmation link
- `{{ .Email }}` - User's email address
- `{{ .Token }}` - Confirmation token
- `{{ .TokenHash }}` - Hashed token
- `{{ .RedirectTo }}` - Redirect URL after confirmation

#### Recommended HTML Template:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Confirm Your Contracto Account</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #1E293B;
            background-color: #F8FAFC;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        .header {
            background: linear-gradient(135deg, #1E293B 0%, #3B82F6 100%);
            color: white;
            padding: 32px;
            text-align: center;
        }
        .logo {
            font-size: 28px;
            font-weight: 800;
            margin-bottom: 8px;
        }
        .tagline {
            font-size: 16px;
            opacity: 0.9;
        }
        .content {
            padding: 32px;
        }
        .welcome {
            font-size: 24px;
            font-weight: 700;
            color: #1E293B;
            margin-bottom: 16px;
        }
        .message {
            font-size: 16px;
            color: #64748B;
            margin-bottom: 24px;
            line-height: 1.6;
        }
        .cta-button {
            display: inline-block;
            background: linear-gradient(135deg, #3B82F6, #1D4ED8);
            color: white;
            text-decoration: none;
            padding: 16px 32px;
            border-radius: 8px;
            font-weight: 600;
            font-size: 16px;
            margin: 24px 0;
            transition: transform 0.2s;
        }
        .cta-button:hover {
            transform: translateY(-2px);
        }
        .info-box {
            background: #F0F9FF;
            border: 1px solid #3B82F6;
            border-radius: 8px;
            padding: 20px;
            margin: 24px 0;
        }
        .info-box h3 {
            color: #3B82F6;
            font-size: 18px;
            margin-bottom: 8px;
        }
        .info-box p {
            color: #64748B;
            font-size: 14px;
            margin: 0;
        }
        .footer {
            background: #F8FAFC;
            padding: 24px 32px;
            text-align: center;
            border-top: 1px solid #E2E8F0;
        }
        .footer p {
            color: #94A3B8;
            font-size: 14px;
            margin: 0;
        }
        .social-links {
            margin-top: 16px;
        }
        .social-links a {
            color: #3B82F6;
            text-decoration: none;
            margin: 0 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Contracto</div>
            <div class="tagline">Professional B2B Contracting Platform</div>
        </div>
        
        <div class="content">
            <h1 class="welcome">Welcome to Contracto! 🎉</h1>
            
            <p class="message">
                Thank you for joining Contracto! We're excited to have you as part of our professional B2B contracting community.
            </p>
            
            <p class="message">
                To complete your account setup and start accessing exclusive deals, managing orders, and connecting with verified suppliers, please confirm your email address by clicking the button below:
            </p>
            
            <div style="text-align: center;">
                <a href="{{ .ConfirmationURL }}" class="cta-button">
                    Confirm Your Email Address
                </a>
            </div>
            
            <div class="info-box">
                <h3>What happens next?</h3>
                <p>
                    Once you confirm your email, you'll have full access to:<br>
                    • Browse thousands of verified suppliers<br>
                    • Access exclusive business deals<br>
                    • Manage your orders and quotations<br>
                    • Track your business expenses<br>
                    • Connect with other professionals
                </p>
            </div>
            
            <p class="message">
                If you didn't create an account with Contracto, you can safely ignore this email.
            </p>
            
            <p class="message">
                <strong>Need help?</strong> Contact our support team at <a href="mailto:support@contracto.com" style="color: #3B82F6;">support@contracto.com</a>
            </p>
        </div>
        
        <div class="footer">
            <p>
                You're receiving this email because you signed up for Contracto.<br>
                If you have any questions, feel free to reach out to us.
            </p>
            <div class="social-links">
                <a href="https://buildcontracto.com">Website</a> |
                <a href="mailto:support@contracto.com">Support</a> |
                <a href="https://buildcontracto.com/privacy">Privacy Policy</a>
            </div>
        </div>
    </div>
</body>
</html>
```

### 3. Customize Password Reset Email

#### Template Variables Available:
- `{{ .SiteURL }}` - Your site URL
- `{{ .ConfirmationURL }}` - Password reset link
- `{{ .Email }}` - User's email address
- `{{ .Token }}` - Reset token
- `{{ .TokenHash }}` - Hashed token
- `{{ .RedirectTo }}` - Redirect URL after reset

#### Recommended HTML Template:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Your Contracto Password</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #1E293B;
            background-color: #F8FAFC;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        .header {
            background: linear-gradient(135deg, #1E293B 0%, #3B82F6 100%);
            color: white;
            padding: 32px;
            text-align: center;
        }
        .logo {
            font-size: 28px;
            font-weight: 800;
            margin-bottom: 8px;
        }
        .tagline {
            font-size: 16px;
            opacity: 0.9;
        }
        .content {
            padding: 32px;
        }
        .title {
            font-size: 24px;
            font-weight: 700;
            color: #1E293B;
            margin-bottom: 16px;
        }
        .message {
            font-size: 16px;
            color: #64748B;
            margin-bottom: 24px;
            line-height: 1.6;
        }
        .cta-button {
            display: inline-block;
            background: linear-gradient(135deg, #EF4444, #DC2626);
            color: white;
            text-decoration: none;
            padding: 16px 32px;
            border-radius: 8px;
            font-weight: 600;
            font-size: 16px;
            margin: 24px 0;
            transition: transform 0.2s;
        }
        .cta-button:hover {
            transform: translateY(-2px);
        }
        .warning-box {
            background: #FEF2F2;
            border: 1px solid #EF4444;
            border-radius: 8px;
            padding: 20px;
            margin: 24px 0;
        }
        .warning-box h3 {
            color: #EF4444;
            font-size: 18px;
            margin-bottom: 8px;
        }
        .warning-box p {
            color: #64748B;
            font-size: 14px;
            margin: 0;
        }
        .footer {
            background: #F8FAFC;
            padding: 24px 32px;
            text-align: center;
            border-top: 1px solid #E2E8F0;
        }
        .footer p {
            color: #94A3B8;
            font-size: 14px;
            margin: 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Contracto</div>
            <div class="tagline">Professional B2B Contracting Platform</div>
        </div>
        
        <div class="content">
            <h1 class="title">Reset Your Password</h1>
            
            <p class="message">
                We received a request to reset the password for your Contracto account associated with <strong>{{ .Email }}</strong>.
            </p>
            
            <p class="message">
                Click the button below to reset your password. This link will expire in 1 hour for security reasons.
            </p>
            
            <div style="text-align: center;">
                <a href="{{ .ConfirmationURL }}" class="cta-button">
                    Reset My Password
                </a>
            </div>
            
            <div class="warning-box">
                <h3>Security Notice</h3>
                <p>
                    If you didn't request this password reset, please ignore this email. 
                    Your password will remain unchanged. For security, this link expires in 1 hour.
                </p>
            </div>
            
            <p class="message">
                <strong>Need help?</strong> Contact our support team at <a href="mailto:support@contracto.com" style="color: #3B82F6;">support@contracto.com</a>
            </p>
        </div>
        
        <div class="footer">
            <p>
                You're receiving this email because a password reset was requested for your Contracto account.<br>
                If you have any questions, feel free to reach out to us.
            </p>
        </div>
    </div>
</body>
</html>
```

### 4. Configure Email Settings

#### In Supabase Dashboard:
1. Go to **Authentication** → **URL Configuration**
2. Set **Site URL** to: `https://contractobuild.com`
3. Set **Redirect URLs** to include:
   - `https://contractobuild.com/emailverified`
   - `https://contractobuild.com/reset-password.html`
   - `https://contractobuild.com/**`
4. Configure **SMTP Settings** (if using custom SMTP):
   - Use your domain's SMTP server
   - Set "From" email to: `noreply@contractobuild.com`

### 5. Test Email Templates

#### Testing Steps:
1. Create a test user account
2. Check the confirmation email format
3. Test password reset functionality
4. Verify redirect URLs work correctly
5. Test on different email clients (Gmail, Outlook, Apple Mail)

### 6. Additional Customizations

#### Email Headers:
- **From Name**: "Contracto Team"
- **From Email**: "noreply@contractobuild.com"
- **Reply-To**: "support@contractobuild.com"

#### Email Footer:
- Add unsubscribe link
- Include company address
- Add social media links
- Include privacy policy link

## Implementation Checklist

- [ ] Update signup confirmation email template
- [ ] Update password reset email template  
- [ ] Configure Site URL in Supabase settings
- [ ] Add `https://contractobuild.com/reset-password.html` and `https://contractobuild.com/emailverified` to allowed redirect list
- [ ] Upload `web/emailverified.html` to `https://contractobuild.com/emailverified`
- [ ] Upload `web/reset-password.html` to `https://contractobuild.com/reset-password.html`
- [ ] Test email delivery and formatting
- [ ] Verify redirect functionality
- [ ] Update SMTP settings (if applicable)
- [ ] Test on multiple email clients

## Troubleshooting

### Common Issues:
1. **Emails not sending**: Check SMTP configuration
2. **Redirect not working**: Verify URL is in allowed list
3. **Template not rendering**: Check HTML syntax
4. **Variables not showing**: Ensure correct variable syntax
5. **Password reset lands on homepage instead of password form**: Ensure `https://contractobuild.com/reset-password.html` is set as the redirect URL in both the app code (`auth_service.dart`) and the Supabase Redirect URLs configuration.

### Support:
- Supabase Documentation: [Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates)
- Contact: support@contracto.com

## Next Steps

After implementing these customizations:
1. Monitor email delivery rates
2. Track user engagement with emails
3. A/B test different email designs
4. Collect user feedback on email experience
5. Optimize based on analytics data
