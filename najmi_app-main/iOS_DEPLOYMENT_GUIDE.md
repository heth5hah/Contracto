# iOS App Deployment Guide - Contracto App

## 📱 **Pre-Deployment Checklist**

### ✅ **Configuration Complete**
- **App Name**: Contracto
- **Bundle ID**: `com.contractobuild.mobile` (production ready)
- **iOS Version**: 12.0+ (minimum deployment target)
- **App Icons**: ✅ Configured with proper sizes
- **Splash Screen**: ✅ Configured
- **Code Signing**: ✅ Development team configured
- **Network Security**: ✅ ATS configured for Supabase

---

## 🚀 **Deployment Options**

### **Option 1: iOS Simulator (Development)**
```bash
# Open iOS Simulator
open -a Simulator

# Run the app
flutter run
```

### **Option 2: Personal Team (Testing)**
```bash
# Build for iOS device
flutter build ios

# Open Xcode project
open ios/Runner.xcworkspace
```

**In Xcode:**
1. Select **Runner** project → **Runner** target
2. Go to **Signing & Capabilities**
3. Select your **Personal Team** (Apple ID)
4. Enable **Automatically manage signing**
5. Build and run on device

### **Option 3: Apple Developer Account (Production)**
```bash
# Build for release
flutter build ios --release
```

**Requirements:**
- Apple Developer Account ($99/year)
- Production certificates
- App Store provisioning profile

---

## 📋 **Current Configuration**

### **Bundle Identifiers**
- **iOS App**: `com.contractobuild.mobile`
- **iOS Tests**: `com.contractobuild.mobile.RunnerTests`
- **Android**: `com.contractobuild.mobile.dev`

### **App Information**
- **Display Name**: Contracto
- **Bundle Name**: Contracto
- **Version**: 1.0.0+1
- **Company**: Contracto & Hardwares Private Limited

### **iOS Deployment Target**
- **Minimum iOS**: 12.0
- **Architecture**: arm64
- **Bitcode**: Disabled (required for Flutter)

---

## 🔧 **Build Commands**

### **Development Build**
```bash
# Clean and get dependencies
flutter clean
flutter pub get

# Install iOS pods
cd ios && pod install && cd ..

# Run on simulator
flutter run
```

### **Release Build**
```bash
# Build for iOS release
flutter build ios --release

# Build without code signing (for CI/CD)
flutter build ios --no-codesign
```

### **Archive for App Store**
```bash
# Build release version
flutter build ios --release

# Open Xcode
open ios/Runner.xcworkspace

# In Xcode: Product → Archive
```

---

## 🏪 **App Store Submission**

### **Prerequisites**
1. **Apple Developer Account** ($99/year)
2. **App Store Connect** access
3. **Production certificates**
4. **App Store provisioning profile**

### **Steps**
1. **Create App in App Store Connect**
   - App Name: Contracto
   - Bundle ID: `com.contractobuild.mobile`
   - SKU: contracto-mobile-2024

2. **Configure App Information**
   - Description
   - Keywords
   - Screenshots (required sizes)
   - App icon (1024x1024)

3. **Build and Upload**
   ```bash
   flutter build ios --release
   # Archive in Xcode and upload to App Store Connect
   ```

4. **Submit for Review**
   - Complete app information
   - Upload screenshots
   - Submit for Apple review

---

## 🔐 **Code Signing Setup**

### **Development (Personal Team)**
```bash
# Open Xcode project
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select Runner project
# 2. Select Runner target
# 3. Signing & Capabilities
# 4. Select Personal Team
# 5. Enable automatic signing
```

### **Production (Apple Developer Account)**
1. **Create App ID**
   - Identifier: `com.contractobuild.mobile`
   - Name: Contracto

2. **Create Provisioning Profile**
   - Type: App Store
   - App ID: `com.contractobuild.mobile`
   - Certificate: Distribution

3. **Download and Install**
   - Download provisioning profile
   - Install in Xcode

---

## 📱 **Required iOS Capabilities**

### **Network Security (Configured)**
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>supabase.co</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.0</string>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### **Encryption Declaration**
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## 🎯 **Testing Checklist**

### **Before Deployment**
- [ ] App launches without crashes
- [ ] All features work on iOS 12.0+
- [ ] App icons display correctly
- [ ] Splash screen shows properly
- [ ] Network requests work (Supabase)
- [ ] Payment integration works (Razorpay)
- [ ] PDF viewing works (WebView)
- [ ] Offline handling works

### **Device Testing**
- [ ] iPhone SE (iOS 12+)
- [ ] iPhone 12/13/14/15
- [ ] iPad (if supported)
- [ ] Different screen sizes

---

## 🚨 **Common Issues & Solutions**

### **Build Errors**
```bash
# Clean and rebuild
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run
```

### **Signing Issues**
- Check Apple Developer account
- Verify certificates are valid
- Use automatic signing
- Try different bundle ID

### **Network Issues**
- Check ATS configuration
- Verify Supabase URL
- Test on device (not simulator)

### **App Store Rejection**
- Check app description
- Verify all required screenshots
- Test on multiple devices
- Follow App Store guidelines

---

## 📞 **Support Resources**

### **Apple Developer**
- [developer.apple.com](https://developer.apple.com)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

### **Flutter iOS**
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [iOS Platform Views](https://docs.flutter.dev/development/platform-integration/platform-views)

### **Troubleshooting**
```bash
# Check Flutter doctor
flutter doctor -v

# Check iOS setup
flutter doctor --verbose

# Check Xcode version
xcodebuild -version
```

---

## ✅ **Success Indicators**

Your app is ready for deployment when:
- ✅ **Builds without errors**
- ✅ **Runs on iOS simulator**
- ✅ **Runs on physical device**
- ✅ **All features work correctly**
- ✅ **App icons display properly**
- ✅ **Network requests succeed**
- ✅ **Code signing works**

---

## 🎉 **Next Steps**

1. **Test thoroughly** on multiple iOS devices
2. **Create App Store Connect** app listing
3. **Prepare marketing materials** (screenshots, description)
4. **Submit for App Store review**
5. **Monitor for crashes** and user feedback

**The Contracto app is now ready for iOS deployment!** 🚀

---

*Last updated: $(date)*
*Configuration: Production Ready*
*Bundle ID: com.contractobuild.mobile*
*App Name: Contracto*
