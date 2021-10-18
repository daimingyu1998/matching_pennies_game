// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

contract MatchingPennies {
    uint256 public constant betAmount = 1 ether;
    uint256 public constant matchingTimeOut = 10 minutes;
    uint256 public constant playingTimeOut = 10 minutes;
    uint256 public constant revealingTimeOut = 10 minutes;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    enum Choice {
        None,
        Head,
        Tail
    }
    enum Player {
        PlayerA,
        PlayerB
    }
    enum Outcomes {
        None,
        PlayerA,
        PlayerB
    }
    enum GameStatus {
        Matching,
        Playing,
        Revealing,
        Calculating
    }
    struct Game {
        address payable playerA;
        address payable playerB;
        bytes32 encryptedChoicePlayerA;
        bytes32 encryptedChoicePlayerB;
        Choice choicePlayerA;
        Choice choicePlayerB;
        GameStatus gameStatus;
        Outcomes outcome;
    }
    Game[] public gameHistory;
    Game public gameOngoing;
    uint256 private matchingDeadline;
    uint256 private playingDeadline;
    uint256 private revealingDeadline;

    constructor() public {
        _status = _NOT_ENTERED;
    }

    modifier equalToBetAmount() {
        require(msg.value == betAmount);
        _;
    }
    modifier registered() {
        require(
            msg.sender == gameOngoing.playerA ||
                msg.sender == gameOngoing.playerB,
            "You haven't registered for the game!"
        );
        _;
    }
    modifier unregistered() {
        require(
            msg.sender != gameOngoing.playerA &&
                msg.sender != gameOngoing.playerB,
            "You have already registered for the game!"
        );
        _;
    }
    modifier matching() {
        require(
            gameOngoing.gameStatus == GameStatus.Matching,
            "Game is not matching!"
        );
        _;
    }
    modifier playing() {
        require(
            gameOngoing.gameStatus == GameStatus.Playing,
            "Game is not playing!"
        );
        _;
    }
    modifier revealing() {
        require(
            gameOngoing.gameStatus == GameStatus.Revealing,
            "Game is not revealing!"
        );
        _;
    }
    modifier calculating() {
        require(
            gameOngoing.gameStatus == GameStatus.Calculating,
            "Game is not calculating!"
        );
        _;
    }
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    function registor()
        external
        payable
        equalToBetAmount
        unregistered
        matching
        returns (string memory)
    {
        if (gameOngoing.playerA == address(0)) {
            gameOngoing.playerA = msg.sender;
            matchingDeadline = now + matchingTimeOut;
            return "Registered as player A";
        } else if (gameOngoing.playerB == address(0)) {
            gameOngoing.playerB = msg.sender;
            gameOngoing.gameStatus = GameStatus.Playing;
            matchingDeadline = 0;
            return "Registered as player B";
        } else {
            revert("Game has started! Register for the next game!");
        }
    }

    function play(bytes32 encryptedChoice) external playing registered {
        if (msg.sender == gameOngoing.playerA) {
            require(
                gameOngoing.encryptedChoicePlayerA == 0,
                "You have already made a choice!"
            );
            gameOngoing.encryptedChoicePlayerA = encryptedChoice;
        } else if (msg.sender == gameOngoing.playerB) {
            require(
                gameOngoing.encryptedChoicePlayerB == 0,
                "You have already made a choice!"
            );
            gameOngoing.encryptedChoicePlayerB = encryptedChoice;
        }
        if (
            gameOngoing.encryptedChoicePlayerA != 0 &&
            gameOngoing.encryptedChoicePlayerB != 0
        ) {
            gameOngoing.gameStatus = GameStatus.Revealing;
            playingDeadline = 0;
        } else {
            playingDeadline = now + playingTimeOut;
        }
    }

    function reveal(uint8 playerChoice, bytes32 randomNumber)
        external
        revealing
        registered
        nonReentrant
    {
        require(
            playerChoice == 1 || playerChoice == 2,
            "You have made a invalid choice!"
        );
        if (msg.sender == gameOngoing.playerA) {
            require(
                gameOngoing.choicePlayerA == Choice.None,
                "You have already revealed a choice!"
            );
            require(
                gameOngoing.encryptedChoicePlayerA ==
                    keccak256(abi.encodePacked(playerChoice, randomNumber)),
                "Your revealing didn't match your choice!"
            );
            if (playerChoice == 1) {
                gameOngoing.choicePlayerA = Choice.Head;
            } else if (playerChoice == 2) {
                gameOngoing.choicePlayerA = Choice.Tail;
            }
        } else if (msg.sender == gameOngoing.playerB) {
            require(
                gameOngoing.choicePlayerB == Choice.None,
                "You have already revealed a choice!"
            );
            require(
                gameOngoing.encryptedChoicePlayerB ==
                    keccak256(abi.encodePacked(playerChoice, randomNumber)),
                "Your revealing didn't match your choice!"
            );
            if (playerChoice == 1) {
                gameOngoing.choicePlayerB = Choice.Head;
            } else if (playerChoice == 2) {
                gameOngoing.choicePlayerB = Choice.Tail;
            }
        }
        if (
            gameOngoing.choicePlayerA != Choice.None &&
            gameOngoing.choicePlayerB != Choice.None
        ) {
            gameOngoing.gameStatus = GameStatus.Calculating;
            revealingDeadline = 0;
            calculate();
        } else {
            revealingDeadline = now + revealingTimeOut;
        }
    }

    function calculate() private {
        address payable winner;
        if (gameOngoing.choicePlayerA == gameOngoing.choicePlayerB) {
            gameOngoing.outcome = Outcomes.PlayerA;
            winner = gameOngoing.playerA;
        } else {
            gameOngoing.outcome = Outcomes.PlayerB;
            winner = gameOngoing.playerB;
        }
        gameHistory.push(gameOngoing);
        reset();
        winner.transfer(2 ether);
    }

    function timeOutCheck() public nonReentrant {
        address payable refundAddress;
        uint256 refundAmount;
        if (gameOngoing.gameStatus == GameStatus.Matching) {
            if (matchingDeadline != 0 && matchingDeadline < now) {
                refundAddress = gameOngoing.playerA;
                refundAmount = 1 ether;
                reset();
            }
        } else if (gameOngoing.gameStatus == GameStatus.Playing) {
            if (playingDeadline != 0 && playingDeadline < now) {
                if (
                    gameOngoing.encryptedChoicePlayerA == 0 &&
                    gameOngoing.encryptedChoicePlayerB == 0
                ) {
                    reset();
                } else if (
                    gameOngoing.encryptedChoicePlayerA != 0 &&
                    gameOngoing.encryptedChoicePlayerB == 0
                ) {
                    refundAddress = gameOngoing.playerA;
                    refundAmount = 2 ether;
                    gameOngoing.outcome = Outcomes.PlayerA;
                } else if (
                    gameOngoing.encryptedChoicePlayerA == 0 &&
                    gameOngoing.encryptedChoicePlayerB != 0
                ) {
                    refundAddress = gameOngoing.playerB;
                    refundAmount = 2 ether;
                    gameOngoing.outcome = Outcomes.PlayerB;
                }
                gameHistory.push(gameOngoing);
                reset();
            }
        } else if (gameOngoing.gameStatus == GameStatus.Revealing) {
            if (revealingDeadline != 0 && revealingDeadline < now) {
                if (
                    gameOngoing.choicePlayerA == Choice.None &&
                    gameOngoing.choicePlayerB == Choice.None
                ) {
                    reset();
                } else if (
                    gameOngoing.choicePlayerA != Choice.None &&
                    gameOngoing.choicePlayerB == Choice.None
                ) {
                    refundAddress = gameOngoing.playerA;
                    refundAmount = 2 ether;
                    gameOngoing.outcome = Outcomes.PlayerA;
                } else if (
                    gameOngoing.choicePlayerA == Choice.None &&
                    gameOngoing.choicePlayerB != Choice.None
                ) {
                    refundAddress = gameOngoing.playerB;
                    refundAmount = 2 ether;
                    gameOngoing.outcome = Outcomes.PlayerB;
                }
                gameHistory.push(gameOngoing);
                reset();
            }
        }
        if (refundAddress != address(0)) {
            refundAddress.transfer(refundAmount);
        }
    }

    function reset() private {
        gameOngoing.playerA = address(0);
        gameOngoing.playerB = address(0);
        gameOngoing.encryptedChoicePlayerA = 0;
        gameOngoing.encryptedChoicePlayerB = 0;
        gameOngoing.gameStatus = GameStatus.Matching;
        gameOngoing.choicePlayerA = Choice.None;
        gameOngoing.choicePlayerB = Choice.None;
        matchingDeadline = 0;
        playingDeadline = 0;
        revealingDeadline = 0;
    }

    function getOngoingGameStatus() public view returns (string memory) {
        if (gameOngoing.gameStatus == GameStatus.Matching) {
            return "Matching";
        } else if (gameOngoing.gameStatus == GameStatus.Playing) {
            return "Playing";
        } else if (gameOngoing.gameStatus == GameStatus.Calculating) {
            return "Calculating";
        }
    }

    function getLastGameInformation()
        public
        view
        returns (
            address,
            address,
            Outcomes
        )
    {
        Game memory game = gameHistory[gameHistory.length - 1];
        return (game.playerA, game.playerB, game.outcome);
    }
}
