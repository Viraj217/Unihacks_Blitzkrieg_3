# Authentication Flow Documentation

## Overview
This document describes the authentication flow for the Beme app using the custom backend API.

## Backend API Endpoints

### Base URL
- Default: `http://localhost:3000` (configured via PORT in .env)

### Endpoints

1. **POST /user/signup**
   - **Body**: `{ "email": "string", "password": "string" }`
   - **Response**: User data on success, error message on failure
   - **Status Codes**: 
     - 200/201: Success
     - 4xx/5xx: Error

2. **POST /user/login**
   - **Body**: `{ "email": "string", "password": "string" }`
   - **Response**: User data with token on success, error message on failure
   - **Status Codes**: 
     - 200: Success
     - 4xx/5xx: Error

## Flutter Implementation

### File Structure
```
lib/
├── services/
│   ├── auth_service.dart          # Backend API auth service
│   └── supabase_service.dart      # Supabase integration (optional)
├── pages/
│   └── onboarding_pages/
│       ├── beme_landing_animation_page.dart  # Landing with video
│       ├── login_page.dart                   # Login form
│       └── signup_page.dart                  # Signup form
└── routes/
    └── app_routes.dart            # Route configuration
```

### User Flow

1. **Landing Page** (`BemeLandingAnimationPage`)
   - Shows "Beme" animation
   - Video background loops
   - Presents "Log In" and "Sign Up" buttons
   - Route: `/`

2. **Sign Up Page** (`SignupPage`)
   - Email input with validation
   - Password input (min 6 chars)
   - Confirm password validation
   - Terms & Conditions checkbox
   - Calls: `POST /user/signup`
   - On success: Navigate to profile setup
   - Route: `/signup`

3. **Login Page** (`LoginPage`)
   - Email input with validation
   - Password input (min 6 chars)
   - "Forgot Password" link
   - Calls: `POST /user/login`
   - On success: Navigate to home
   - Route: `/login`

### Features

#### Visual Design
- **Glassmorphism**: Frosted glass effect on forms and buttons
- **Animations**: Smooth fade-in and slide-up transitions
- **Gradient Background**: Purple gradient from main.dart
- **Form Validation**: Real-time input validation
- **Loading States**: Visual feedback during API calls

#### Form Validation
- **Email**: Checks for @ and . characters
- **Password**: Minimum 6 characters
- **Confirm Password**: Must match password
- **Terms**: Must be accepted for signup

#### Error Handling
- Network errors caught and displayed
- Backend errors shown via SnackBar
- Success messages displayed
- Form validation errors inline

### AuthService Usage

```dart
// Sign up
final response = await AuthService.signUp(
  email: 'user@example.com',
  password: 'password123',
);

if (response.success) {
  // Handle success
  print(response.data);
} else {
  // Handle error
  print(response.message);
}

// Login
final response = await AuthService.login(
  email: 'user@example.com',
  password: 'password123',
);

if (response.success) {
  // Handle success
  print(response.data);
} else {
  // Handle error
  print(response.message);
}
```

### Configuration

Make sure your `.env` file contains:
```
PORT=3000
```

The auth service will use `http://localhost:3000` by default.

### Next Steps

1. **Start Backend Server**: Make sure your Express backend is running on port 3000
2. **Token Storage**: Consider adding secure token storage (e.g., flutter_secure_storage)
3. **Session Management**: Implement token refresh and logout
4. **Error Messages**: Customize error messages based on backend responses
5. **Social Auth**: Add Google/Apple sign-in if needed

### Design Notes

- All pages use the global gradient background
- Glassmorphism creates a premium feel
- Smooth animations enhance user experience
- Validation provides clear feedback
- Responsive design works on all screen sizes

## Testing

To test the authentication flow:

1. Start your backend server
2. Run the Flutter app
3. Navigate through: Landing → Sign Up → Create account
4. Navigate through: Landing → Log In → Enter credentials
5. Verify API calls in backend logs
