# Play Store Listing Assets

This directory contains assets and documentation for the Google Play Store listing.

## Required Assets

### App Icon

- **Location**: `android/app/src/main/res/mipmap-*/`
- **Status**: ✅ Already configured (adaptive icon)
- **Format**: Adaptive icon with background and foreground layers

### Feature Graphic

- **Size**: 1024 x 500 px
- **Format**: PNG or JPEG
- **Status**: ⏳ To be created
- **Description**: Main banner image shown at the top of the Play Store listing

### Screenshots

- **Phone**: Minimum 2, maximum 8 screenshots
- **Recommended size**: 1080 x 1920 px (9:16 aspect ratio)
- **Tablet** (optional): 1200 x 1920 px or 1600 x 2560 px
- **Status**: ⏳ To be created
- **Suggested screenshots**:
  1. Main translation screen with multiple language results
  2. Image translation feature in action
  3. Translation history with search
  4. Language selection sheet
  5. Romanization feature demonstration

### Promotional Video (Optional)

- **Length**: 30 seconds to 2 minutes
- **Format**: YouTube URL
- **Status**: ⏳ Optional

## Store Listing Copy

### Short Description

(Max 80 characters)

```
Translate text into 59+ languages instantly. Private & offline.
```

### Full Description

(Max 4000 characters)

```
Lingko - Private Offline Translation

Translate text into 59+ languages instantly, all on your device. No internet required after downloading language packs.

✨ KEY FEATURES

🌍 59+ Languages
Translate between Arabic, Chinese, Czech, Danish, Dutch, English, Finnish, French, German, Greek, Hebrew, Hindi, Hungarian, Indonesian, Italian, Japanese, Korean, Norwegian, Polish, Portuguese, Romanian, Russian, Slovak, Spanish, Swedish, Thai, Turkish, Ukrainian, Vietnamese, and many more.

📸 Image Translation
Extract and translate text from photos using your camera or gallery. Perfect for signs, menus, documents, and more.

🔄 Multi-Language Translation
Translate your text into multiple languages simultaneously. Compare translations side-by-side.

🔤 Romanization
Get phonetic romanization for non-Latin scripts (Arabic, Chinese, Greek, Hebrew, Hindi, Japanese, Korean, Russian, Thai, Ukrainian).

📝 Translation History
All your translations are saved locally. Search and access them anytime.

🎯 Smart Language Detection
Automatically detects the source language of your text.

🔊 Text-to-Speech
Hear the pronunciation of translations in 50+ languages.

🔒 PRIVACY FIRST

• No data collection or tracking
• No analytics or telemetry
• All translations happen on your device
• No internet required after downloading language models
• Your data never leaves your device

🎨 MODERN DESIGN

• Material You dynamic theming
• Dark mode support
• Smooth animations and transitions
• Adaptive layouts for phones and tablets
• Full accessibility support

📱 REQUIREMENTS

• Android 8.0 (API 26) or higher
• Internet connection for initial language model downloads
• ~50-200 MB per language model

🆓 COMPLETELY FREE

• No ads
• No in-app purchases
• No subscriptions
• Open source

Perfect for travelers, students, language learners, and anyone who needs quick, private translations.
```

### App Category

- **Primary**: Tools
- **Secondary**: Education

### Content Rating

- **Target**: Everyone
- **Content**: No objectionable content

### Tags/Keywords

```
translation, translator, language, multilingual, offline, private, ML Kit,
text recognition, OCR, romanization, phrasebook, dictionary, travel,
language learning, education, productivity
```

## Privacy Policy

- **URL**: Link to `PRIVACY.md` in repository or hosted version

## Support Information

- **Website**: GitHub repository URL
- **Email**: Developer email
- **Support URL**: GitHub Issues page

## Release Notes Template

### Version 1.0.0 (Initial Release)

```
🎉 Initial release of Lingko!

✨ Features:
• Translate text into 59+ languages
• Image text recognition and translation
• Multi-language simultaneous translation
• Romanization for non-Latin scripts
• Translation history with search
• Text-to-speech for translations
• Completely offline after language downloads
• Privacy-focused: no data collection

🎨 Design:
• Material You dynamic theming
• Dark mode support
• Smooth animations
• Tablet-optimized layouts

All translations happen on your device. Your privacy is our priority.
```

## Testing Checklist

Before submitting to Play Store:

- [ ] Test on multiple device sizes (phone, tablet)
- [ ] Test on different Android versions (8.0, 12, 13, 14, 15)
- [ ] Verify all screenshots are accurate
- [ ] Test deep links (if any)
- [ ] Verify app signing configuration
- [ ] Test release build thoroughly
- [ ] Ensure privacy policy is accessible
- [ ] Verify all permissions are necessary and documented
- [ ] Test offline functionality
- [ ] Verify language model downloads work
- [ ] Test with TalkBack (accessibility)
- [ ] Check app size and APK/AAB size

## Notes

- Keep screenshots updated with each major release
- Update description to highlight new features
- Respond to user reviews promptly
- Monitor crash reports and fix issues quickly
- Consider A/B testing different feature graphics
