-include .env

# Ensure ~/.foundry/bin is in PATH for forge / cast / anvil
export PATH := $(HOME)/.foundry/bin:$(PATH)

.PHONY: help build fmt clean sim exploit test-fallback owner balance storage

# Find script matching LEVEL (e.g. LEVEL=01 matches script/01-Fallback.s.sol)
SCRIPT = $(shell find script -maxdepth 1 -name "$(LEVEL)-*.s.sol" 2>/dev/null | head -n 1)

help:
	@echo "Ethernaut Foundry Helper"
	@echo "  make sim LEVEL=01      - Simulate exploit locally against live RPC state"
	@echo "  make exploit LEVEL=01  - Broadcast exploit to the network"
	@echo "  make test-fallback     - Run local Fallback unit/PoC test"
	@echo "  make owner             - Read owner() of INSTANCE_ADDRESS via cast"
	@echo "  make balance           - Check balance of INSTANCE_ADDRESS via cast"
	@echo "  make build             - Compile contracts"
	@echo "  make fmt               - Format Solidity code"

# --- Compilation & Quality ---
build:
	forge build

fmt:
	forge fmt

clean:
	forge clean

# --- Testing ---
test-fallback:
	forge test --match-contract FallbackTest -vvvv

# --- Challenge Interaction ---
# Dry-run / Simulation (Zero gas spent, instant trace)
sim:
	@if [ -z "$(LEVEL)" ]; then echo "Error: specify LEVEL (e.g. make sim LEVEL=01)"; exit 1; fi
	@if [ -z "$(SCRIPT)" ]; then echo "Error: script for LEVEL=$(LEVEL) not found in script/"; exit 1; fi
	forge script $(SCRIPT) --rpc-url $(RPC_URL) -vvvv

# Real execution on-chain
exploit:
	@if [ -z "$(LEVEL)" ]; then echo "Error: specify LEVEL (e.g. make exploit LEVEL=01)"; exit 1; fi
	@if [ -z "$(SCRIPT)" ]; then echo "Error: script for LEVEL=$(LEVEL) not found in script/"; exit 1; fi
	forge script $(SCRIPT) --rpc-url $(RPC_URL) --broadcast -vvvv

# --- Live Instance Inspection via Cast ---
owner:
	@cast call $(INSTANCE_ADDRESS) "owner()(address)" --rpc-url $(RPC_URL)

balance:
	@cast balance $(INSTANCE_ADDRESS) --rpc-url $(RPC_URL)

wins:
	@cast call $(INSTANCE_ADDRESS) "consecutiveWins()(uint256)" --rpc-url $(RPC_URL)

# Inspect a specific storage slot (e.g. make storage SLOT=0)
storage:
	@cast storage $(INSTANCE_ADDRESS) $(SLOT) --rpc-url $(RPC_URL)
