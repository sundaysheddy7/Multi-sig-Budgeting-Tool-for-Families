
import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const contractName = "Multi-sig-Budgeting-Tool-for-Families";

describe("Multi-sig Budgeting Tool Tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("initializes contract correctly", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "initialize",
      [Cl.uint(2), Cl.uint(144)],
      address1
    );
    expect(result).toBeOk(Cl.bool(true));
  });

  it("adds family member successfully", () => {
    // Initialize first
    simnet.callPublicFn(contractName, "initialize", [Cl.uint(2), Cl.uint(144)], address1);
    
    const { result } = simnet.callPublicFn(
      contractName,
      "add-family-member",
      [Cl.principal(address2)],
      address1
    );
    expect(result).toBeOk(Cl.bool(true));
  });

  it("sets expense goal successfully", () => {
    // Initialize first
    simnet.callPublicFn(contractName, "initialize", [Cl.uint(2), Cl.uint(144)], address1);
    
    const { result } = simnet.callPublicFn(
      contractName,
      "set-expense-goal",
      [Cl.stringAscii("food"), Cl.uint(5000), Cl.uint(1)],
      address1
    );
    expect(result).toBeOk(Cl.bool(true));
  });

  it("generates expense report successfully", () => {
    // Initialize first
    simnet.callPublicFn(contractName, "initialize", [Cl.uint(2), Cl.uint(144)], address1);
    
    const { result } = simnet.callPublicFn(
      contractName,
      "generate-expense-report",
      [Cl.uint(1), Cl.uint(3), Cl.none()],
      address1
    );
    expect(result).toBeOk(expect.any(Object));
  });

  it("retrieves expense goal correctly", () => {
    // Initialize and set goal
    simnet.callPublicFn(contractName, "initialize", [Cl.uint(2), Cl.uint(144)], address1);
    simnet.callPublicFn(
      contractName,
      "set-expense-goal",
      [Cl.stringAscii("transport"), Cl.uint(3000), Cl.uint(2)],
      address1
    );
    
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-expense-goal",
      [Cl.principal(address1), Cl.stringAscii("transport"), Cl.uint(2)],
      address1
    );
    expect(result).toBeSome(expect.any(Object));
  });

  it("creates budget category successfully", () => {
    // Initialize first
    simnet.callPublicFn(contractName, "initialize", [Cl.uint(2), Cl.uint(144)], address1);
    
    const { result } = simnet.callPublicFn(
      contractName,
      "create-budget-category",
      [Cl.stringAscii("entertainment"), Cl.uint(2000)],
      address1
    );
    expect(result).toBeOk(Cl.bool(true));
  });

  it("gets spending comparison between members", () => {
    // Initialize and add member
    simnet.callPublicFn(contractName, "initialize", [Cl.uint(2), Cl.uint(144)], address1);
    simnet.callPublicFn(contractName, "add-family-member", [Cl.principal(address2)], address1);
    
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-spending-comparison",
      [Cl.principal(address1), Cl.principal(address2), Cl.uint(1), Cl.stringAscii("food")],
      address1
    );
    expect(result).toEqual(expect.any(Object));
  });

  it("predicts monthly spending based on trends", () => {
    // Initialize first
    simnet.callPublicFn(contractName, "initialize", [Cl.uint(2), Cl.uint(144)], address1);
    
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "predict-monthly-spending",
      [Cl.principal(address1), Cl.stringAscii("utilities"), Cl.uint(4)],
      address1
    );
    expect(result).toBeUint(0);
  });

  it("checks member status correctly", () => {
    // Initialize first
    simnet.callPublicFn(contractName, "initialize", [Cl.uint(2), Cl.uint(144)], address1);
    
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "is-member",
      [Cl.principal(address1)],
      address1
    );
    expect(result).toStrictEqual(Cl.bool(true));
  });

  it("gets current month correctly", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-current-month",
      [],
      address1
    );
    expect(result).toBeUint(0);
  });
});
