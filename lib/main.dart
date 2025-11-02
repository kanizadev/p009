import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SnakeGameApp());
}

class SnakeGameApp extends StatelessWidget {
  const SnakeGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF87A96B)),
        useMaterial3: true,
      ),
      home: const SnakeGame(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum Direction { up, down, left, right }

class DirectionIntent extends Intent {
  final Direction direction;
  const DirectionIntent(this.direction);
}

enum GameState { playing, paused, gameOver, ready }

enum GameMode { classic, hard, endless }

enum FoodType { normal, bonus, golden }

enum PowerUpType { speedBoost, shield, extraLife }

class PowerUp {
  final PowerUpType type;
  final Position position;
  final DateTime spawnTime;
  final Duration duration;

  PowerUp({
    required this.type,
    required this.position,
    required this.spawnTime,
    this.duration = const Duration(seconds: 10),
  });

  bool get isExpired => DateTime.now().difference(spawnTime) > duration;
}

class GameStats {
  int totalGames = 0;
  int totalScore = 0;
  int bestScore = 0;
  int totalFoodEaten = 0;
  int totalCombo = 0;
  int longestSnake = 0;
  Map<String, int> achievements = {};

  double get averageScore => totalGames > 0 ? totalScore / totalGames : 0;
}

class Position {
  final int x;
  final int y;

  Position(this.x, this.y);

  @override
  bool operator ==(Object other) {
    return other is Position && other.x == x && other.y == y;
  }

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class GridPainter extends CustomPainter {
  final int boardSize;

  GridPainter({required this.boardSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw subtle grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    // Draw accent lines at center
    final accentPaint = Paint()
      ..color = const Color(0xFF87A96B).withValues(alpha: 0.15)
      ..strokeWidth = 1;

    final cellWidth = size.width / boardSize;
    final cellHeight = size.height / boardSize;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw vertical lines
    for (int i = 0; i <= boardSize; i++) {
      final x = i * cellWidth;
      final isCenter = (i == boardSize / 2);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isCenter ? accentPaint : gridPaint,
      );
    }

    // Draw horizontal lines
    for (int i = 0; i <= boardSize; i++) {
      final y = i * cellHeight;
      final isCenter = (i == boardSize / 2);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isCenter ? accentPaint : gridPaint,
      );
    }

    // Draw center cross accent
    canvas.drawLine(
      Offset(centerX - 20, centerY),
      Offset(centerX + 20, centerY),
      accentPaint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - 20),
      Offset(centerX, centerY + 20),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> with TickerProviderStateMixin {
  static const int boardSize = 20;
  static const Duration gameSpeed = Duration(milliseconds: 200);

  List<Position> snake = [Position(10, 10)];
  Position food = Position(5, 5);
  FoodType foodType = FoodType.normal;
  List<Position> obstacles = [];
  List<PowerUp> powerUps = [];
  Direction currentDirection = Direction.right;
  GameState gameState = GameState.ready;
  GameMode gameMode = GameMode.classic;
  GameStats stats = GameStats();
  int score = 0;
  int highScore = 0;
  int combo = 0;
  int maxCombo = 0;
  bool hasShield = false;
  int lives = 1;
  DateTime? shieldEndTime;
  Timer? gameTimer;
  Timer? powerUpTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _generateFood();
    _loadStats();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  void _loadStats() {
    // In a real app, load from shared preferences
    stats.bestScore = highScore;
  }

  void _saveStats() {
    // In a real app, save to shared preferences
    if (score > stats.bestScore) {
      stats.bestScore = score;
    }
    stats.totalGames++;
    stats.totalScore += score;
    // totalFoodEaten is already updated when food is eaten, no need to increment here
    stats.totalCombo += combo;
    if (snake.length > stats.longestSnake) {
      stats.longestSnake = snake.length;
    }
    highScore = stats.bestScore;
    _checkAchievements();
  }

  void _checkAchievements() {
    if (score >= 100 && !stats.achievements.containsKey('centurion')) {
      stats.achievements['centurion'] = 1;
    }
    if (score >= 500 && !stats.achievements.containsKey('master')) {
      stats.achievements['master'] = 1;
    }
    if (maxCombo >= 10 && !stats.achievements.containsKey('combo_king')) {
      stats.achievements['combo_king'] = 1;
    }
    if (snake.length >= 50 && !stats.achievements.containsKey('long_snake')) {
      stats.achievements['long_snake'] = 1;
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    powerUpTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      snake = [Position(10, 10)];
      currentDirection = Direction.right;
      gameState = GameState.playing;
      score = 0;
      combo = 0;
      maxCombo = 0;
      hasShield = false;
      shieldEndTime = null;
      lives = 1;
      obstacles = [];
      powerUps = [];
      foodType = FoodType.normal;
      _generateObstacles();
      _generatePowerUp();
    });
    _generateFood();
    _startGameTimer();
    _startPowerUpTimer();
  }

  void _generateObstacles() {
    if (gameMode == GameMode.hard) {
      Random random = Random();
      obstacles = [];
      int obstacleCount = 5 + (score ~/ 100) * 2;
      obstacleCount = obstacleCount.clamp(5, 15);

      for (int i = 0; i < obstacleCount; i++) {
        Position obstacle;
        int attempts = 0;
        do {
          obstacle = Position(
            random.nextInt(boardSize),
            random.nextInt(boardSize),
          );
          attempts++;
        } while ((snake.contains(obstacle) ||
                obstacles.contains(obstacle) ||
                obstacle == food) &&
            attempts < 100);
        if (attempts < 100) {
          obstacles.add(obstacle);
        }
      }
    }
  }

  void _generatePowerUp() {
    if (gameMode == GameMode.hard || gameMode == GameMode.endless) {
      Random random = Random();
      if (random.nextDouble() < 0.3) {
        Position powerUpPos;
        int attempts = 0;
        do {
          powerUpPos = Position(
            random.nextInt(boardSize),
            random.nextInt(boardSize),
          );
          attempts++;
        } while ((snake.contains(powerUpPos) ||
                obstacles.contains(powerUpPos) ||
                powerUpPos == food) &&
            attempts < 100);

        if (attempts < 100) {
          PowerUpType type =
              PowerUpType.values[random.nextInt(PowerUpType.values.length)];
          powerUps.add(
            PowerUp(
              type: type,
              position: powerUpPos,
              spawnTime: DateTime.now(),
            ),
          );
        }
      }
    }
  }

  void _startPowerUpTimer() {
    powerUpTimer?.cancel();
    powerUpTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (gameState == GameState.playing) {
        _generatePowerUp();
      }
    });
  }

  void _startGameTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(gameSpeed, (timer) {
      if (gameState == GameState.playing) {
        _moveSnake();
      } else {
        timer.cancel();
      }
    });
  }

  void _pauseGame() {
    if (gameState != GameState.ready && gameState != GameState.gameOver) {
      setState(() {
        if (gameState == GameState.playing) {
          gameState = GameState.paused;
          gameTimer?.cancel();
        } else {
          gameState = GameState.playing;
          _startGameTimer();
        }
      });
    }
  }

  void _moveSnake() {
    // Check game state before moving
    if (gameState != GameState.playing) {
      return;
    }

    Position head = snake.first;
    Position newHead;

    switch (currentDirection) {
      case Direction.up:
        newHead = Position(head.x, head.y - 1);
        break;
      case Direction.down:
        newHead = Position(head.x, head.y + 1);
        break;
      case Direction.left:
        newHead = Position(head.x - 1, head.y);
        break;
      case Direction.right:
        newHead = Position(head.x + 1, head.y);
        break;
    }

    // Wrap position in endless mode
    if (gameMode == GameMode.endless) {
      newHead = _wrapPosition(newHead);
    }

    // Check shield expiration before collision
    if (hasShield && shieldEndTime != null) {
      if (DateTime.now().isAfter(shieldEndTime!)) {
        setState(() {
          hasShield = false;
          shieldEndTime = null;
        });
      }
    }

    // Check collisions
    if (_isCollision(newHead)) {
      if (hasShield) {
        setState(() {
          hasShield = false;
          shieldEndTime = null;
        });
        HapticFeedback.lightImpact();
        return;
      }
      if (lives > 0 && gameMode == GameMode.endless) {
        setState(() {
          lives--;
          // Find a safe position for the snake to respawn
          Random random = Random();
          Position respawnPos = Position(10, 10);
          int attempts = 0;
          while ((obstacles.contains(respawnPos) ||
                  powerUps.any((p) => p.position == respawnPos) ||
                  respawnPos == food) &&
              attempts < 100) {
            respawnPos = Position(
              random.nextInt(boardSize),
              random.nextInt(boardSize),
            );
            attempts++;
          }
          snake = [respawnPos];
          currentDirection = Direction.right;
          combo = 0;
        });
        _generateFood();
        return;
      }
      _gameOver();
      return;
    }

    // Update snake position and check items
    setState(() {
      snake.insert(0, newHead);

      // Check and remove expired power-ups first
      powerUps.removeWhere((powerUp) => powerUp.isExpired);

      // Check power-ups
      powerUps.removeWhere((powerUp) {
        if (newHead == powerUp.position) {
          _activatePowerUp(powerUp.type);
          HapticFeedback.mediumImpact();
          return true;
        }
        return false;
      });

      // Check if food is eaten
      if (newHead == food) {
        int points = _getFoodPoints();

        // Combo system
        combo++;
        if (combo > maxCombo) maxCombo = combo;
        int comboMultiplier = (combo ~/ 3).clamp(1, 5);
        points = (points * comboMultiplier).round();

        score += points;
        stats.totalFoodEaten++;
        _generateFood();
        HapticFeedback.lightImpact();
      } else {
        snake.removeLast();
        combo = 0; // Reset combo if food not eaten
      }
    });
  }

  int _getFoodPoints() {
    switch (foodType) {
      case FoodType.normal:
        return 10;
      case FoodType.bonus:
        return 25;
      case FoodType.golden:
        return 50;
    }
  }

  void _activatePowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.speedBoost:
        // Speed boost removed - just add points instead
        setState(() {
          score += 20;
        });
        break;
      case PowerUpType.shield:
        setState(() {
          hasShield = true;
          shieldEndTime = DateTime.now().add(const Duration(seconds: 10));
        });
        break;
      case PowerUpType.extraLife:
        setState(() {
          lives++;
        });
        break;
    }
  }

  bool _isCollision(Position position) {
    // Wall collision (only in classic and hard modes)
    // Note: In endless mode, walls wrap around, so no collision
    if (gameMode != GameMode.endless) {
      if (position.x < 0 ||
          position.x >= boardSize ||
          position.y < 0 ||
          position.y >= boardSize) {
        return true;
      }
    }

    // Obstacle collision
    if (obstacles.contains(position)) {
      return true;
    }

    // Self collision (check body segments, excluding the tail which will be removed)
    // Only check from index 0 (head) to length-2 (before tail)
    for (int i = 0; i < snake.length - 1; i++) {
      if (snake[i] == position) {
        return true;
      }
    }

    return false;
  }

  Position _wrapPosition(Position position) {
    int x = position.x;
    int y = position.y;

    if (x < 0) x = boardSize - 1;
    if (x >= boardSize) x = 0;
    if (y < 0) y = boardSize - 1;
    if (y >= boardSize) y = 0;

    return Position(x, y);
  }

  void _generateFood() {
    Random random = Random();
    Position newFood;
    FoodType newFoodType;

    // Determine food type based on score and mode
    double bonusChance = 0.15 + (score / 1000).clamp(0.0, 0.3);
    double goldenChance = 0.05 + (score / 2000).clamp(0.0, 0.15);

    double roll = random.nextDouble();
    if (roll < goldenChance) {
      newFoodType = FoodType.golden;
    } else if (roll < goldenChance + bonusChance) {
      newFoodType = FoodType.bonus;
    } else {
      newFoodType = FoodType.normal;
    }

    int attempts = 0;
    List<Position> occupiedPositions = [
      ...snake,
      ...obstacles,
      ...powerUps.map((p) => p.position),
    ];

    do {
      newFood = Position(random.nextInt(boardSize), random.nextInt(boardSize));
      attempts++;
    } while (occupiedPositions.contains(newFood) && attempts < 100);

    if (attempts >= 100) {
      // Fallback: find any free position
      bool found = false;
      for (int x = 0; x < boardSize && !found; x++) {
        for (int y = 0; y < boardSize && !found; y++) {
          Position pos = Position(x, y);
          if (!occupiedPositions.contains(pos)) {
            newFood = pos;
            found = true;
          }
        }
      }
      // If board is completely full, place food at a safe default position
      if (!found) {
        newFood = Position(0, 0);
        // Remove first obstacle if needed to make room
        if (obstacles.isNotEmpty && gameMode == GameMode.hard) {
          obstacles.removeAt(0);
        }
      }
    }

    setState(() {
      food = newFood;
      foodType = newFoodType;
    });
  }

  void _gameOver() {
    if (gameState == GameState.playing) {
      gameTimer?.cancel();
      powerUpTimer?.cancel();
      HapticFeedback.heavyImpact();

      setState(() {
        gameState = GameState.gameOver;
      });
      _saveStats();
    }
  }

  void _changeDirection(Direction newDirection) {
    if (gameState != GameState.playing) return;

    // Prevent reversing into itself
    if ((currentDirection == Direction.up && newDirection == Direction.down) ||
        (currentDirection == Direction.down && newDirection == Direction.up) ||
        (currentDirection == Direction.left &&
            newDirection == Direction.right) ||
        (currentDirection == Direction.right &&
            newDirection == Direction.left)) {
      return;
    }

    setState(() {
      currentDirection = newDirection;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final isLandscape = size.width > size.height;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionIntent(
          Direction.up,
        ),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionIntent(
          Direction.down,
        ),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionIntent(
          Direction.left,
        ),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionIntent(
          Direction.right,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyW): const DirectionIntent(
          Direction.up,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyS): const DirectionIntent(
          Direction.down,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyA): const DirectionIntent(
          Direction.left,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyD): const DirectionIntent(
          Direction.right,
        ),
      },
      child: Actions(
        actions: {
          DirectionIntent: CallbackAction<DirectionIntent>(
            onInvoke: (intent) {
              _changeDirection(intent.direction);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [
                    const Color(0xFFE8F5E9),
                    const Color(0xFFC8E6C9),
                    const Color(0xFFA5D6A7),
                    const Color(0xFF81C784),
                    const Color(0xFF66BB6A),
                  ],
                  stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
                ),
              ),
              child: SafeArea(
                child: isLandscape && isTablet
                    ? Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildHeader(
                                  isTablet: isTablet,
                                  isLandscape: isLandscape,
                                ),
                                const SizedBox(height: 20),
                                _buildControls(
                                  isTablet: isTablet,
                                  isLandscape: isLandscape,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: _buildGameBoard(
                              isTablet: isTablet,
                              isLandscape: isLandscape,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildHeader(
                            isTablet: isTablet,
                            isLandscape: isLandscape,
                          ),
                          Expanded(
                            child: _buildGameBoard(
                              isTablet: isTablet,
                              isLandscape: isLandscape,
                            ),
                          ),
                          _buildControls(
                            isTablet: isTablet,
                            isLandscape: isLandscape,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isTablet, required bool isLandscape}) {
    final padding = isTablet ? 24.0 : (isLandscape ? 12.0 : 16.0);
    final titleFontSize = isTablet ? 28.0 : (isLandscape ? 18.0 : 22.0);
    final infoFontSize = isTablet ? 14.0 : (isLandscape ? 10.0 : 12.0);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.5),
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.2),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.6),
                width: 2.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, -3),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _buildScoreCard(
                  'SCORE',
                  '$score',
                  const Color(0xFF87A96B),
                  isTablet: isTablet,
                  isLandscape: isLandscape,
                ),
              ),
              Flexible(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 28 : (isLandscape ? 18 : 24),
                            vertical: isTablet ? 14 : (isLandscape ? 10 : 12),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF87A96B).withValues(alpha: 0.85),
                                const Color(0xFF9CAF88).withValues(alpha: 0.85),
                                Colors.white.withValues(alpha: 0.5),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF87A96B,
                                ).withValues(alpha: 0.5),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, -5),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Text(
                            'SNAKE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (gameState == GameState.playing &&
                        (combo > 0 ||
                            (gameMode == GameMode.endless && lives > 0) ||
                            hasShield)) ...[
                      SizedBox(height: isTablet ? 10 : (isLandscape ? 6 : 8)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet
                                  ? 14
                                  : (isLandscape ? 10 : 12),
                              vertical: isTablet ? 8 : (isLandscape ? 4 : 6),
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(
                                    0xFF9CAF88,
                                  ).withValues(alpha: 0.6),
                                  Colors.white.withValues(alpha: 0.25),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF9CAF88,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (combo > 0) ...[
                                  Icon(
                                    Icons.star,
                                    size: infoFontSize,
                                    color: Colors.amber.shade700,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'x$combo',
                                    style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontSize: infoFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                                if (gameMode == GameMode.endless &&
                                    lives > 0) ...[
                                  if (combo > 0) SizedBox(width: 12),
                                  ...List.generate(
                                    lives,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(
                                        right: index < lives - 1 ? 4 : 0,
                                      ),
                                      child: Icon(
                                        Icons.favorite,
                                        size: infoFontSize * 1.1,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  ),
                                ],
                                if (hasShield) ...[
                                  if (combo > 0 ||
                                      (gameMode == GameMode.endless &&
                                          lives > 0))
                                    SizedBox(width: 12),
                                  Icon(
                                    Icons.shield,
                                    size: infoFontSize * 1.1,
                                    color: Colors.purple.shade400,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (gameState == GameState.paused) ...[
                      SizedBox(height: isTablet ? 10 : (isLandscape ? 6 : 8)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet
                                  ? 16
                                  : (isLandscape ? 12 : 14),
                              vertical: isTablet ? 8 : (isLandscape ? 4 : 6),
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(
                                    0xFF788F6B,
                                  ).withValues(alpha: 0.7),
                                  Colors.white.withValues(alpha: 0.25),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF788F6B,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              'PAUSED',
                              style: TextStyle(
                                color: const Color(0xFF788F6B),
                                fontSize: isTablet
                                    ? 16.0
                                    : (isLandscape ? 12.0 : 14.0),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: _buildScoreCard(
                  'BEST',
                  '$highScore',
                  const Color(0xFF788F6B),
                  isTablet: isTablet,
                  isLandscape: isLandscape,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(
    String label,
    String value,
    Color accentColor, {
    required bool isTablet,
    required bool isLandscape,
  }) {
    final paddingH = isTablet ? 20.0 : (isLandscape ? 12.0 : 16.0);
    final paddingV = isTablet ? 14.0 : (isLandscape ? 10.0 : 12.0);
    final labelSize = isTablet ? 13.0 : (isLandscape ? 10.0 : 11.0);
    final valueSize = isTablet ? 36.0 : (isLandscape ? 24.0 : 28.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: paddingH,
            vertical: paddingV,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.6),
                Colors.white.withValues(alpha: 0.45),
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.3),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 12),
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, -5),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF788F6B),
                  fontSize: labelSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: isTablet ? 6 : 4),
              Text(
                value,
                style: TextStyle(
                  color: const Color(0xFF2D3A2D),
                  fontSize: valueSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameBoard({required bool isTablet, required bool isLandscape}) {
    final margin = isTablet ? 24.0 : (isLandscape ? 12.0 : 16.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate optimal size - use available space but maintain square
        final maxSize = isLandscape
            ? constraints.maxHeight
            : (constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight * 0.7);

        return Center(
          child: Container(
            width: maxSize - (margin * 2),
            height: maxSize - (margin * 2),
            margin: EdgeInsets.all(margin),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.5),
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.15),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, -8),
                  spreadRadius: -3,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.white.withValues(alpha: 0.25),
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      if (gameState != GameState.playing) return;

                      final double dx = details.delta.dx;
                      final double dy = details.delta.dy;

                      if (dx.abs() > dy.abs()) {
                        _changeDirection(
                          dx > 0 ? Direction.right : Direction.left,
                        );
                      } else {
                        _changeDirection(
                          dy > 0 ? Direction.down : Direction.up,
                        );
                      }
                    },
                    child: Stack(
                      children: [
                        _buildGridBackground(),
                        _buildGrid(),
                        if (gameState == GameState.ready ||
                            gameState == GameState.gameOver)
                          _buildGameOverlay(
                            isTablet: isTablet,
                            isLandscape: isLandscape,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            const Color(0xFFF8FAF7),
            const Color(0xFFF0F4EF),
            const Color(0xFFE8EDE7),
          ],
        ),
      ),
      child: CustomPaint(painter: GridPainter(boardSize: boardSize)),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: boardSize,
      ),
      itemCount: boardSize * boardSize,
      itemBuilder: (context, index) {
        int x = index % boardSize;
        int y = index ~/ boardSize;
        Position position = Position(x, y);

        bool isSnakeHead = snake.isNotEmpty && snake.first == position;
        bool isSnakeBody = snake.contains(position) && !isSnakeHead;
        bool isFood = food == position;
        bool isObstacle = obstacles.contains(position);

        // Find power-up at this position (if any)
        PowerUp? powerUp;
        try {
          powerUp = powerUps.firstWhere(
            (p) => p.position == position && !p.isExpired,
          );
        } catch (e) {
          powerUp = null;
        }
        bool hasPowerUp = powerUp != null;

        Color foodColor;
        Color borderColor;
        switch (foodType) {
          case FoodType.normal:
            foodColor = const Color(0xFF87A96B);
            borderColor = Colors.white;
            break;
          case FoodType.bonus:
            foodColor = const Color(0xFF9CAF88);
            borderColor = Colors.amber.shade300;
            break;
          case FoodType.golden:
            foodColor = Colors.amber.shade400;
            borderColor = Colors.orange.shade400;
            break;
        }

        return Container(
          margin: const EdgeInsets.all(1),
          child: isFood
              ? AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              foodColor,
                              foodColor.withValues(alpha: 0.8),
                              foodColor.withValues(alpha: 0.6),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: foodColor.withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 4,
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: foodType == FoodType.golden ? 12 : 10,
                            height: foodType == FoodType.golden ? 12 : 10,
                            decoration: BoxDecoration(
                              color: borderColor,
                              borderRadius: BorderRadius.circular(
                                foodType == FoodType.golden ? 6 : 5,
                              ),
                              boxShadow: foodType == FoodType.golden
                                  ? [
                                      BoxShadow(
                                        color: Colors.amber.withValues(
                                          alpha: 0.8,
                                        ),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : hasPowerUp
              ? AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    Color powerUpColor;
                    IconData powerUpIcon;
                    if (powerUp != null) {
                      switch (powerUp.type) {
                        case PowerUpType.speedBoost:
                          powerUpColor = Colors.blue.shade400;
                          powerUpIcon = Icons.speed;
                          break;
                        case PowerUpType.shield:
                          powerUpColor = Colors.purple.shade400;
                          powerUpIcon = Icons.shield;
                          break;
                        case PowerUpType.extraLife:
                          powerUpColor = Colors.red.shade400;
                          powerUpIcon = Icons.favorite;
                          break;
                      }
                    } else {
                      powerUpColor = Colors.blue.shade400;
                      powerUpIcon = Icons.speed;
                    }
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              powerUpColor,
                              powerUpColor.withValues(alpha: 0.7),
                              powerUpColor.withValues(alpha: 0.5),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: powerUpColor.withValues(alpha: 0.7),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.4),
                              blurRadius: 4,
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                        child: Icon(
                          powerUpIcon,
                          size: 18,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : isObstacle
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey.shade600,
                        Colors.grey.shade800,
                        Colors.grey.shade900,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: -1,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                )
              : isSnakeHead
              ? Container(
                  decoration: BoxDecoration(
                    color: hasShield
                        ? Colors.purple.shade400
                        : const Color(0xFF87A96B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasShield
                          ? Colors.purple.shade200
                          : Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: hasShield
                        ? [
                            BoxShadow(
                              color: Colors.purple.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: const Color(
                                0xFF87A96B,
                              ).withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                )
              : isSnakeBody
              ? Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF9CAF88),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildGameOverlay({bool isTablet = false, bool isLandscape = false}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(
              isTablet ? 24.0 : (isLandscape ? 12.0 : 20.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gameState == GameState.gameOver) ...[
                  Text(
                    'GAME OVER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 42.0 : (isLandscape ? 28.0 : 36.0),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : (isLandscape ? 12 : 16)),
                  Text(
                    'Score: $score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 32.0 : (isLandscape ? 22.0 : 28.0),
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  if (score == highScore && score > 0) ...[
                    SizedBox(height: isTablet ? 12 : (isLandscape ? 10 : 12)),
                    Text(
                      'NEW HIGH SCORE!',
                      style: TextStyle(
                        color: Colors.amber.shade300,
                        fontSize: isTablet ? 20.0 : (isLandscape ? 16.0 : 18.0),
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _startGame,
                        borderRadius: BorderRadius.circular(24),
                        splashColor: Colors.white.withValues(alpha: 0.3),
                        highlightColor: Colors.white.withValues(alpha: 0.15),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet
                                ? 56.0
                                : (isLandscape ? 40.0 : 48.0),
                            vertical: isTablet
                                ? 20.0
                                : (isLandscape ? 16.0 : 20.0),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF87A96B).withValues(alpha: 0.85),
                                const Color(0xFF9CAF88).withValues(alpha: 0.85),
                                Colors.white.withValues(alpha: 0.4),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF87A96B,
                                ).withValues(alpha: 0.5),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                                spreadRadius: 3,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, -5),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                gameState == GameState.ready
                                    ? Icons.play_arrow_rounded
                                    : Icons.refresh_rounded,
                                color: Colors.white,
                                size: isTablet
                                    ? 28.0
                                    : (isLandscape ? 20.0 : 24.0),
                              ),
                              SizedBox(width: 10),
                              Text(
                                gameState == GameState.ready
                                    ? 'START'
                                    : 'PLAY AGAIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet
                                      ? 24.0
                                      : (isLandscape ? 18.0 : 20.0),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls({required bool isTablet, required bool isLandscape}) {
    final padding = isTablet ? 24.0 : (isLandscape ? 12.0 : 16.0);
    final iconSize = isTablet ? 40.0 : (isLandscape ? 28.0 : 32.0);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.refresh,
            onPressed: gameState != GameState.ready ? _startGame : null,
            color: const Color(0xFF87A96B),
            iconSize: iconSize,
          ),
          _buildControlButton(
            icon: gameState == GameState.playing
                ? Icons.pause
                : Icons.play_arrow,
            onPressed:
                gameState != GameState.ready && gameState != GameState.gameOver
                ? _pauseGame
                : null,
            color: const Color(0xFF9CAF88),
            iconSize: iconSize,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    required double iconSize,
  }) {
    final bool isEnabled = onPressed != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isEnabled
                  ? [
                      color.withValues(alpha: 0.75),
                      color.withValues(alpha: 0.6),
                      Colors.white.withValues(alpha: 0.35),
                    ]
                  : [
                      Colors.grey[400]!.withValues(alpha: 0.5),
                      Colors.grey[400]!.withValues(alpha: 0.3),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: isEnabled ? 0.6 : 0.3),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isEnabled
                    ? color.withValues(alpha: 0.35)
                    : Colors.grey.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(18),
              splashColor: Colors.white.withValues(alpha: 0.2),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: Container(
                padding: const EdgeInsets.all(14),
                child: Icon(icon, color: Colors.white, size: iconSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
