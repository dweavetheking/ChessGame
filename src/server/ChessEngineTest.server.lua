--!strict
--[=[
	Temporary test script to validate the ChessEngine module.
	This should be run on the server in a test environment.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Assuming the script is placed in ServerScriptService, adjust paths as needed
local Shared = ServerScriptService.src.shared
-- local Shared = ReplicatedStorage.src.shared -- Or wherever your Rojo setup places it

local ChessEngine = require(Shared.ChessEngine)
local GameTypes = require(Shared.GameTypes)

local function runTests()
	print("Running ChessEngine tests...")

	-- Test 1: newGame() creates a valid board
	local board = ChessEngine.newGame()
	assert(board[1][1].pieceType == GameTypes.PieceTypes.Rook, "Test 1.1 Failed: White Rook missing")
	assert(board[7][4].pieceType == GameTypes.PieceTypes.Pawn, "Test 1.2 Failed: Black Pawn missing")
	assert(board[1][5].pieceType == GameTypes.PieceTypes.King, "Test 1.3 Failed: White King missing")
	print("Test 1 Passed: newGame() is correct.")

	-- Test 2: Legal pawn move
	local isLegal, reason = ChessEngine.isMoveLegal(board, { x = 5, y = 2 }, { x = 5, y = 4 }, GameTypes.Colors.White)
	assert(isLegal, "Test 2.1 Failed: e2-e4 should be a legal first move. Reason: " .. (reason or "nil"))
	print("Test 2 Passed: Legal pawn move (e2-e4) is correct.")

	-- Test 3: Illegal pawn move
	isLegal, reason = ChessEngine.isMoveLegal(board, { x = 5, y = 2 }, { x = 5, y = 5 }, GameTypes.Colors.White)
	assert(not isLegal, "Test 3.1 Failed: e2-e5 should be illegal.")
	print("Test 3 Passed: Illegal pawn move (e2-e5) is correctly identified.")

	-- Test 4: Move opponent's piece
	isLegal, reason = ChessEngine.isMoveLegal(board, { x = 5, y = 7 }, { x = 5, y = 5 }, GameTypes.Colors.White)
	assert(not isLegal, "Test 4.1 Failed: White should not be able to move Black's pawn.")
	print("Test 4 Passed: Moving opponent's piece is correctly blocked.")

	-- Test 5: A simple move sequence
	-- 1. e4
	local board_e4 = ChessEngine.applyMove(board, { x = 5, y = 2 }, { x = 5, y = 4 })
	assert(board_e4[4][5].pieceType == GameTypes.PieceTypes.Pawn, "Test 5.1 Failed: Pawn not at e4")
	assert(board_e4[2][5] == nil, "Test 5.2 Failed: Pawn should be gone from e2")
	-- 2. e5
	local board_e5 = ChessEngine.applyMove(board_e4, { x = 5, y = 7 }, { x = 5, y = 5 })
	assert(board_e5[5][5].pieceType == GameTypes.PieceTypes.Pawn, "Test 5.3 Failed: Black pawn not at e5")
	-- 3. Nf3
	local board_nf3 = ChessEngine.applyMove(board_e5, { x = 7, y = 1 }, { x = 6, y = 3 })
	assert(board_nf3[3][6].pieceType == GameTypes.PieceTypes.Knight, "Test 5.4 Failed: Knight not at f3")
	print("Test 5 Passed: Simple move sequence works correctly.")

	-- Test 6: Check detection
	local checkBoard = ChessEngine.newGame()
	checkBoard[4][5] = checkBoard[1][4] -- Move White Queen to e4
	checkBoard[1][4] = nil
	local inCheck = ChessEngine.isCheck(checkBoard, GameTypes.Colors.Black)
	assert(inCheck, "Test 6.1 Failed: Black King should be in check by the Queen at e4.")
	print("Test 6 Passed: Check detection is working.")

	-- Test 7: Checkmate detection (Scholar's Mate)
	local checkmateBoard = ChessEngine.newGame()
	-- 1. e4 e5
	checkmateBoard = ChessEngine.applyMove(checkmateBoard, { x = 5, y = 2 }, { x = 5, y = 4 })
	checkmateBoard = ChessEngine.applyMove(checkmateBoard, { x = 5, y = 7 }, { x = 5, y = 5 })
	-- 2. Qh5 Nc6
	checkmateBoard = ChessEngine.applyMove(checkmateBoard, { x = 4, y = 1 }, { x = 8, y = 5 })
	checkmateBoard = ChessEngine.applyMove(checkmateBoard, { x = 2, y = 8 }, { x = 3, y = 6 })
	-- 3. Bc4 Nf6?? (mistake)
	checkmateBoard = ChessEngine.applyMove(checkmateBoard, { x = 6, y = 1 }, { x = 3, y = 4 })
	checkmateBoard = ChessEngine.applyMove(checkmateBoard, { x = 7, y = 8 }, { x = 6, y = 6 })
	-- 4. Qxf7#
	checkmateBoard = ChessEngine.applyMove(checkmateBoard, { x = 8, y = 5 }, { x = 6, y = 7 })
	local isMate = ChessEngine.isCheckmate(checkmateBoard, GameTypes.Colors.Black)
	assert(isMate, "Test 7.1 Failed: Scholar's mate should be checkmate.")
	print("Test 7 Passed: Checkmate detection is working.")

	-- Test 8: Pawn Promotion
	local promotionBoard = ChessEngine.newGame()
	promotionBoard[7][1] = { pieceType = "Pawn", color = "White", id = "promo_pawn" } -- Place white pawn at a7
	promotionBoard[2][1] = nil -- remove original pawn
	local promotedBoard = ChessEngine.applyMove(promotionBoard, { x = 1, y = 7 }, { x = 1, y = 8 }, GameTypes.PieceTypes.Queen)
	local newPiece = promotedBoard[8][1]
	assert(newPiece and newPiece.pieceType == GameTypes.PieceTypes.Queen, "Test 8.1 Failed: Pawn did not promote to a Queen.")
	assert(newPiece.color == GameTypes.Colors.White, "Test 8.2 Failed: Promoted piece has the wrong color.")
	print("Test 8 Passed: Pawn promotion is working correctly.")


	print("All ChessEngine tests passed!")
end

runTests()

return {}
