-- AO table test
CREATE TABLE yezzey_test_ao (
    id INT,
    data TEXT
) WITH (appendonly=true);

-- Insert test data
INSERT INTO yezzey_test_ao (id, data) 
SELECT i, md5(random()::text) 
FROM generate_series(1, 10000) i;


-- AOCS table test
CREATE TABLE yezzey_test_aocs (
    id INT,
    col1 INT,
    col2 INT,
    data TEXT
) WITH (appendonly=true, orientation=column);

-- Insert test data
INSERT INTO yezzey_test_aocs (id, col1, col2, data) 
SELECT i, i, i, md5(random()::text) 
FROM generate_series(1, 10000) i;
