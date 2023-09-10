CREATE TABLE transactions (
    id INTEGER PRIMARY KEY,
    date TEXT,
    debit_id INTEGER,
    credit_id INTEGER,
    amount INTEGER,
    note TEXT,
    group_name TEXT
);
