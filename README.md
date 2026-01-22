# 🐍 Snake Game

A modern, beautiful Snake game built with Flutter featuring glassmorphism UI, multiple game modes, power-ups, and advanced gameplay mechanics.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

## ✨ Features

### 🎮 Gameplay
- **Classic Mode**: Traditional snake gameplay with wall collisions
- **Hard Mode**: Obstacles and power-ups for added challenge
- **Endless Mode**: Wrap-around walls, extra lives, and unlimited gameplay
- **Power-ups**: Shield, extra life, and bonus points
- **Multiple Food Types**: Normal, bonus, and golden food with different point values
- **Combo System**: Chain food consumption for score multipliers
- **Statistics Tracking**: Track your best score, longest snake, and more

### 🎨 Design
- **Glassmorphism UI**: Beautiful frosted glass effects throughout
- **Smooth Animations**: Pulsing effects on food and power-ups
- **Responsive Design**: Optimized for phones, tablets, and landscape mode
- **Modern Gradients**: Beautiful color schemes and visual effects
- **Clean Interface**: Simple, intuitive user interface

### 🎯 Controls
- **Touch/Swipe**: Swipe gestures on mobile devices
- **Keyboard**: Arrow keys or WASD keys for desktop/web
- **Directional Buttons**: On-screen control buttons (optional)

## 📸 Screenshots

<img src="https://raw.githubusercontent.com/kanizadev/p009/refs/heads/main/image.png" hight=446 width=243 /> <img src="https://raw.githubusercontent.com/kanizadev/p009/refs/heads/main/image1.png" hight=446 width=243 /> <img src="https://raw.githubusercontent.com/kanizadev/p009/refs/heads/main/image2.png" hight=446 width=243 />


### Build for Platforms

- **Android**: `flutter build apk`
- **iOS**: `flutter build ios`
- **Web**: `flutter build web`
- **Windows**: `flutter build windows`
- **macOS**: `flutter build macos`
- **Linux**: `flutter build linux`

## 🎮 How to Play

1. **Start the Game**: Tap or click the "START" button on the home screen
2. **Control the Snake**: 
   - Swipe on mobile devices to change direction
   - Use arrow keys or WASD on desktop
3. **Eat Food**: Collect food to grow your snake and increase your score
4. **Avoid Collisions**: Don't hit walls, obstacles, or your own body
5. **Collect Power-ups**: 
   - **Shield**: Protects you from one collision (purple glow)
   - **Extra Life**: Adds an extra life in endless mode (red heart)
   - **Bonus Points**: Grants bonus points (blue speed icon)

### Food Types

- **Normal Food** (Green): 10 points
- **Bonus Food** (Light Green): 25 points
- **Golden Food** (Amber): 50 points

### Combo System

Eat food consecutively to build combos! Every 3 foods in a row multiplies your score:
- 1-2 foods: 1x multiplier
- 3-5 foods: 2x multiplier
- 6-8 foods: 3x multiplier
- 9-11 foods: 4x multiplier
- 12+ foods: 5x multiplier (maximum)

## 🎯 Game Modes

### Classic Mode
- Traditional snake gameplay
- Wall collisions end the game
- No obstacles or power-ups

### Hard Mode
- Obstacles appear on the board
- Power-ups spawn randomly
- Increased difficulty as score increases

### Endless Mode
- Walls wrap around (snake passes through borders)
- Extra lives available
- Power-ups spawn frequently
- Unlimited gameplay potential

## 🏆 Achievements

Track your progress with built-in achievements:
- **Centurion**: Score 100+ points
- **Master**: Score 500+ points
- **Combo King**: Achieve 10+ combo
- **Long Snake**: Reach 50+ snake length

## 🛠️ Technologies

- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **Material Design 3**: Modern UI components
- **Custom Painters**: Grid background rendering
- **Animation Controllers**: Smooth animations
- **Glassmorphism**: Frosted glass effects


## 🎨 Key Components

- **Game State Management**: Playing, Paused, Game Over, Ready
- **Snake Logic**: Movement, collision detection, food consumption
- **Power-up System**: Spawn timers, expiration, activation
- **Statistics Tracking**: Game stats and achievements
- **Responsive UI**: Adaptive layouts for different screen sizes
- **Glassmorphism Effects**: BackdropFilter with blur and gradients

## 🎮 Controls Reference

| Input | Action |
|-------|--------|
| Arrow Up / W | Move Up |
| Arrow Down / S | Move Down |
| Arrow Left / A | Move Left |
| Arrow Right / D | Move Right |
| Swipe Gestures | Change direction (mobile) |


## 👨‍💻 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/kanizadev/p009/issues).

## 🙏 Acknowledgments

- Classic Snake game for inspiration
- Flutter team for the amazing framework
- Material Design for UI guidelines

---

Made with ❤️ using Flutter
