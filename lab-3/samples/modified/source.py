"""Simple deposit calculator."""

INTEREST_RATE = 0.50


def deposit(amount: float, years: int) -> float:
    for _ in range(years):
        amount *= 1 + INTEREST_RATE
    return round(amount, 2)


if __name__ == "__main__":
    print(deposit(10_000, 5))
