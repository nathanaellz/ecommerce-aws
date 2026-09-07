#!/bin/bash

# ============================================================
# E-COMMERCE CRUD SYSTEM
# Amazon Linux 2023
# Apache + PHP + MariaDB
# ============================================================

set -e

echo "=========================================="
echo " Starting E-Commerce System Installation"
echo "=========================================="


# ============================================================
# 1. UPDATE AMAZON LINUX
# ============================================================

dnf update -y


# ============================================================
# 2. INSTALL REQUIRED SOFTWARE
# ============================================================

echo "Installing Apache, PHP, MariaDB and utilities..."

dnf install -y \
    httpd \
    php \
    php-mysqli \
    mariadb105-server \
    curl


# ============================================================
# 3. START SERVICES
# ============================================================

echo "Starting Apache..."

systemctl enable httpd
systemctl start httpd

echo "Starting MariaDB..."

systemctl enable mariadb
systemctl start mariadb


# ============================================================
# 4. CREATE DATABASE
# ============================================================

echo "Creating e-commerce database..."

mariadb <<'SQL'

CREATE DATABASE IF NOT EXISTS ecommerce;

CREATE USER IF NOT EXISTS 'ecomuser'@'localhost'
IDENTIFIED BY 'ecompassword';

GRANT ALL PRIVILEGES
ON ecommerce.*
TO 'ecomuser'@'localhost';

FLUSH PRIVILEGES;

USE ecommerce;


# ============================================================
# PRODUCTS TABLE
# ============================================================

CREATE TABLE IF NOT EXISTS products (

    id INT AUTO_INCREMENT PRIMARY KEY,

    name VARCHAR(150) NOT NULL,

    category VARCHAR(100) NOT NULL,

    description TEXT,

    price DECIMAL(10,2) NOT NULL,

    stock INT NOT NULL DEFAULT 0,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);


# ============================================================
# ORDERS TABLE
# ============================================================

CREATE TABLE IF NOT EXISTS orders (

    id INT AUTO_INCREMENT PRIMARY KEY,

    product_id INT NOT NULL,

    product_name VARCHAR(150) NOT NULL,

    quantity INT NOT NULL,

    total DECIMAL(10,2) NOT NULL,

    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);


# ============================================================
# SAMPLE PRODUCTS
# ============================================================

INSERT INTO products
(name, category, description, price, stock)
VALUES

(
    'iPhone 16',
    'Phones',
    'Apple iPhone 16 smartphone',
    3999.00,
    15
),

(
    'Samsung Galaxy S25',
    'Phones',
    'Samsung Galaxy S25 smartphone',
    3599.00,
    12
),

(
    'Google Pixel 9',
    'Phones',
    'Google Pixel 9 smartphone',
    2999.00,
    10
),

(
    'iPad Air',
    'Tablets',
    'Apple iPad Air tablet',
    2799.00,
    10
),

(
    'Samsung Galaxy Tab S10',
    'Tablets',
    'Samsung Galaxy Tab S10 tablet',
    3299.00,
    8
),

(
    'MacBook Air M3',
    'Laptops',
    'Apple MacBook Air with M3 chip',
    4999.00,
    7
),

(
    'Dell Inspiron 15',
    'Laptops',
    'Dell Inspiron 15 laptop',
    2899.00,
    10
),

(
    'ASUS ROG Gaming Laptop',
    'Laptops',
    'High-performance gaming laptop',
    5999.00,
    6
),

(
    'Sony WH-1000XM5',
    'Audio',
    'Wireless noise cancelling headphones',
    1599.00,
    10
),

(
    'Logitech MX Master 3S',
    'Accessories',
    'Wireless productivity mouse',
    399.00,
    20
),

(
    'Keychron K2',
    'Accessories',
    'Mechanical wireless keyboard',
    349.00,
    15
);

SQL


# ============================================================
# 5. REMOVE APACHE DEFAULT PAGE
# ============================================================

rm -f /var/www/html/index.html


# ============================================================
# 6. CREATE DATABASE CONFIGURATION
# ============================================================

cat > /var/www/html/config.php <<'PHP'
<?php

$host = "localhost";
$dbname = "ecommerce";
$username = "ecomuser";
$password = "ecompassword";

$conn = new mysqli(
    $host,
    $username,
    $password,
    $dbname
);

if ($conn->connect_error) {

    die(
        "Database connection failed: "
        . $conn->connect_error
    );

}

$conn->set_charset("utf8mb4");

?>
PHP


# ============================================================
# 7. CREATE E-COMMERCE APPLICATION
# ============================================================

cat > /var/www/html/index.php <<'PHP'
<?php

require_once "config.php";


// ============================================================
// CREATE PRODUCT
// ============================================================

if (isset($_POST["create_product"])) {

    $name = trim($_POST["name"]);
    $category = trim($_POST["category"]);
    $description = trim($_POST["description"]);

    $price = floatval($_POST["price"]);
    $stock = intval($_POST["stock"]);

    if (
        $name !== "" &&
        $category !== "" &&
        $price >= 0 &&
        $stock >= 0
    ) {

        $stmt = $conn->prepare(
            "INSERT INTO products
            (name, category, description, price, stock)
            VALUES (?, ?, ?, ?, ?)"
        );

        $stmt->bind_param(
            "sssdi",
            $name,
            $category,
            $description,
            $price,
            $stock
        );

        $stmt->execute();

        $stmt->close();
    }

    header("Location: index.php");
    exit;
}


// ============================================================
// UPDATE PRODUCT
// ============================================================

if (isset($_POST["update_product"])) {

    $id = intval($_POST["id"]);

    $name = trim($_POST["name"]);
    $category = trim($_POST["category"]);
    $description = trim($_POST["description"]);

    $price = floatval($_POST["price"]);
    $stock = intval($_POST["stock"]);

    if (
        $id > 0 &&
        $name !== "" &&
        $category !== "" &&
        $price >= 0 &&
        $stock >= 0
    ) {

        $stmt = $conn->prepare(
            "UPDATE products

             SET
                name = ?,
                category = ?,
                description = ?,
                price = ?,
                stock = ?

             WHERE id = ?"
        );

        $stmt->bind_param(
            "sssdis",
            $name,
            $category,
            $description,
            $price,
            $stock,
            $id
        );

        $stmt->execute();

        $stmt->close();
    }

    header("Location: index.php");
    exit;
}


// ============================================================
// DELETE PRODUCT
// ============================================================

if (isset($_GET["delete"])) {

    $id = intval($_GET["delete"]);

    if ($id > 0) {

        $stmt = $conn->prepare(
            "DELETE FROM products WHERE id = ?"
        );

        $stmt->bind_param("i", $id);

        $stmt->execute();

        $stmt->close();
    }

    header("Location: index.php");
    exit;
}


// ============================================================
// PURCHASE PRODUCT
// ============================================================

if (isset($_POST["purchase_product"])) {

    $id = intval($_POST["product_id"]);

    $quantity = intval($_POST["quantity"]);

    if ($quantity < 1) {
        $quantity = 1;
    }


    // Get product

    $stmt = $conn->prepare(
        "SELECT name, price, stock
         FROM products
         WHERE id = ?"
    );

    $stmt->bind_param("i", $id);

    $stmt->execute();

    $result = $stmt->get_result();

    $product = $result->fetch_assoc();

    $stmt->close();


    if ($product && $product["stock"] >= $quantity) {

        $total =
            $product["price"] * $quantity;


        // Reduce stock

        $stmt = $conn->prepare(
            "UPDATE products

             SET stock = stock - ?

             WHERE id = ?
             AND stock >= ?"
        );

        $stmt->bind_param(
            "iii",
            $quantity,
            $id,
            $quantity
        );

        $stmt->execute();

        $updated = $stmt->affected_rows > 0;

        $stmt->close();


        if ($updated) {

            // Record order

            $stmt = $conn->prepare(
                "INSERT INTO orders
                (product_id, product_name, quantity, total)
                VALUES (?, ?, ?, ?)"
            );

            $stmt->bind_param(
                "isid",
                $id,
                $product["name"],
                $quantity,
                $total
            );

            $stmt->execute();

            $stmt->close();

            $message =
                "Purchase successful! "
                . $product["name"]
                . " x "
                . $quantity
                . " = RM "
                . number_format($total, 2);

        } else {

            $message =
                "Purchase failed. "
                . "Insufficient stock.";

        }

    } else {

        $message =
            "Purchase failed. "
            . "Not enough stock available.";

    }
}


// ============================================================
// EDIT PRODUCT
// ============================================================

$editProduct = null;

if (isset($_GET["edit"])) {

    $id = intval($_GET["edit"]);

    $stmt = $conn->prepare(
        "SELECT *
         FROM products
         WHERE id = ?"
    );

    $stmt->bind_param("i", $id);

    $stmt->execute();

    $result = $stmt->get_result();

    $editProduct = $result->fetch_assoc();

    $stmt->close();
}


// ============================================================
// SEARCH PRODUCTS
// ============================================================

$search = "";

if (isset($_GET["search"])) {

    $search = trim($_GET["search"]);

}


if ($search !== "") {

    $stmt = $conn->prepare(
        "SELECT *
         FROM products

         WHERE name LIKE ?
         OR category LIKE ?

         ORDER BY id DESC"
    );

    $keyword = "%" . $search . "%";

    $stmt->bind_param(
        "ss",
        $keyword,
        $keyword
    );

    $stmt->execute();

    $products = $stmt->get_result();

} else {

    $products = $conn->query(
        "SELECT *
         FROM products
         ORDER BY id DESC"
    );

}


// ============================================================
// GET ORDERS
// ============================================================

$orders = $conn->query(
    "SELECT *
     FROM orders
     ORDER BY order_date DESC"
);

?>

<!DOCTYPE html>

<html>

<head>

<meta charset="UTF-8">

<meta name="viewport"
      content="width=device-width, initial-scale=1">

<title>TechMart E-Commerce</title>


<style>

* {
    box-sizing: border-box;
}


body {

    margin: 0;

    font-family:
        Arial,
        Helvetica,
        sans-serif;

    background: #f4f6f8;

    color: #222;
}


header {

    background: #111827;

    color: white;

    padding: 25px;

    text-align: center;
}


header h1 {

    margin: 0;

    font-size: 32px;
}


header p {

    margin-bottom: 0;

    color: #d1d5db;
}


.container {

    width: 92%;

    max-width: 1200px;

    margin: 30px auto;
}


.card {

    background: white;

    padding: 25px;

    margin-bottom: 25px;

    border-radius: 12px;

    box-shadow:
        0 2px 10px
        rgba(0,0,0,0.08);
}


h2 {

    margin-top: 0;
}


.form-grid {

    display: grid;

    grid-template-columns:
        repeat(auto-fit, minmax(200px, 1fr));

    gap: 10px;
}


input,
textarea,
select {

    width: 100%;

    padding: 11px;

    border: 1px solid #d1d5db;

    border-radius: 6px;

    font-size: 14px;
}


textarea {

    min-height: 80px;

    resize: vertical;
}


button {

    padding: 11px 16px;

    border: none;

    border-radius: 6px;

    cursor: pointer;

    background: #2563eb;

    color: white;

    font-weight: bold;
}


button:hover {

    opacity: 0.9;
}


.products {

    display: grid;

    grid-template-columns:
        repeat(auto-fit, minmax(250px, 1fr));

    gap: 20px;
}


.product {

    border: 1px solid #e5e7eb;

    border-radius: 10px;

    padding: 20px;

    background: white;
}


.product h3 {

    margin-top: 0;
}


.price {

    font-size: 22px;

    font-weight: bold;

    margin: 10px 0;
}


.stock {

    color: #16a34a;

    font-weight: bold;
}


.out {

    color: #dc2626;

    font-weight: bold;
}


.actions {

    margin-top: 15px;

    display: flex;

    gap: 8px;

    flex-wrap: wrap;
}


.delete {

    background: #dc2626;
}


.edit {

    background: #f59e0b;
}


.success {

    background: #dcfce7;

    border: 1px solid #86efac;

    color: #166534;

    padding: 15px;

    border-radius: 8px;

    margin-bottom: 20px;
}


table {

    width: 100%;

    border-collapse: collapse;
}


th,
td {

    padding: 12px;

    border-bottom: 1px solid #e5e7eb;

    text-align: left;
}


th {

    background: #f3f4f6;
}


.search {

    display: flex;

    gap: 10px;
}


.search input {

    flex: 1;
}


@media(max-width: 700px) {

    table {

        font-size: 12px;
    }

}

</style>

</head>


<body>


<header>

    <h1>🛒 TechMart</h1>

    <p>
        E-Commerce Product Management System
    </p>

</header>


<div class="container">


<?php if (isset($message)): ?>

<div class="success">

    <?php echo htmlspecialchars($message); ?>

</div>

<?php endif; ?>


<!-- ========================================================
     CREATE / UPDATE
========================================================= -->

<div class="card">

<?php if ($editProduct): ?>

    <h2>✏️ Update Product</h2>

    <form method="POST">

        <input
            type="hidden"
            name="id"
            value="<?php
                echo $editProduct["id"];
            ?>"
        >

        <div class="form-grid">

            <input
                type="text"
                name="name"
                placeholder="Product name"
                value="<?php
                    echo htmlspecialchars(
                        $editProduct["name"]
                    );
                ?>"
                required
            >

            <input
                type="text"
                name="category"
                placeholder="Category"
                value="<?php
                    echo htmlspecialchars(
                        $editProduct["category"]
                    );
                ?>"
                required
            >

            <input
                type="number"
                name="price"
                step="0.01"
                min="0"
                placeholder="Price"
                value="<?php
                    echo $editProduct["price"];
                ?>"
                required
            >

            <input
                type="number"
                name="stock"
                min="0"
                placeholder="Stock"
                value="<?php
                    echo $editProduct["stock"];
                ?>"
                required
            >

        </div>

        <br>

        <textarea
            name="description"
            placeholder="Description"
        ><?php
            echo htmlspecialchars(
                $editProduct["description"]
            );
        ?></textarea>

        <br><br>

        <button
            type="submit"
            name="update_product"
        >
            Update Product
        </button>

        <a href="index.php">

            <button type="button">
                Cancel
            </button>

        </a>

    </form>


<?php else: ?>


    <h2>➕ Add New Product</h2>

    <form method="POST">

        <div class="form-grid">

            <input
                type="text"
                name="name"
                placeholder="Product name"
                required
            >

            <input
                type="text"
                name="category"
                placeholder="Category"
                required
            >

            <input
                type="number"
                name="price"
                step="0.01"
                min="0"
                placeholder="Price (RM)"
                required
            >

            <input
                type="number"
                name="stock"
                min="0"
                placeholder="Stock quantity"
                required
            >

        </div>

        <br>

        <textarea
            name="description"
            placeholder="Product description"
        ></textarea>

        <br><br>

        <button
            type="submit"
            name="create_product"
        >
            Add Product
        </button>

    </form>


<?php endif; ?>

</div>


<!-- ========================================================
     SEARCH
========================================================= -->

<div class="card">

    <h2>🔎 Search Products</h2>

    <form
        method="GET"
        class="search"
    >

        <input
            type="text"
            name="search"
            placeholder="Search phones, laptops, tablets..."
            value="<?php
                echo htmlspecialchars($search);
            ?>"
        >

        <button type="submit">
            Search
        </button>

        <a href="index.php">

            <button type="button">
                Reset
            </button>

        </a>

    </form>

</div>


<!-- ========================================================
     PRODUCTS
========================================================= -->

<div class="card">

    <h2>🛍️ Products</h2>

    <div class="products">


<?php while ($product = $products->fetch_assoc()): ?>


        <div class="product">

            <h3>

                <?php
                    echo htmlspecialchars(
                        $product["name"]
                    );
                ?>

            </h3>


            <p>

                <strong>Category:</strong>

                <?php
                    echo htmlspecialchars(
                        $product["category"]
                    );
                ?>

            </p>


            <p>

                <?php
                    echo htmlspecialchars(
                        $product["description"]
                    );
                ?>

            </p>


            <div class="price">

                RM
                <?php
                    echo number_format(
                        $product["price"],
                        2
                    );
                ?>

            </div>


            <?php if ($product["stock"] > 0): ?>

                <p class="stock">

                    ✓
                    <?php
                        echo $product["stock"];
                    ?>
                    available

                </p>


                <!-- PURCHASE -->

                <form method="POST">

                    <input
                        type="hidden"
                        name="product_id"
                        value="<?php
                            echo $product["id"];
                        ?>"
                    >

                    <input
                        type="number"
                        name="quantity"
                        value="1"
                        min="1"
                        max="<?php
                            echo $product["stock"];
                        ?>"
                        required
                    >

                    <br><br>

                    <button
                        type="submit"
                        name="purchase_product"
                    >

                        🛒 Purchase

                    </button>

                </form>


            <?php else: ?>

                <p class="out">

                    ✗ Out of stock

                </p>

            <?php endif; ?>


            <div class="actions">

                <a href="index.php?edit=<?php
                    echo $product["id"];
                ?>">

                    <button
                        type="button"
                        class="edit"
                    >

                        ✏️ Edit

                    </button>

                </a>


                <a
                    href="index.php?delete=<?php
                        echo $product["id"];
                    ?>"
                    onclick="return confirm(
                        'Delete this product?'
                    );"
                >

                    <button
                        type="button"
                        class="delete"
                    >

                        🗑️ Delete

                    </button>

                </a>

            </div>

        </div>


<?php endwhile; ?>


    </div>

</div>


<!-- ========================================================
     ORDERS
========================================================= -->

<div class="card">

    <h2>📦 Purchase History</h2>


    <table>

        <tr>

            <th>Order ID</th>

            <th>Product</th>

            <th>Quantity</th>

            <th>Total</th>

            <th>Date</th>

        </tr>


<?php while ($order = $orders->fetch_assoc()): ?>

        <tr>

            <td>

                #<?php
                    echo $order["id"];
                ?>

            </td>


            <td>

                <?php
                    echo htmlspecialchars(
                        $order["product_name"]
                    );
                ?>

            </td>


            <td>

                <?php
                    echo $order["quantity"];
                ?>

            </td>


            <td>

                RM
                <?php
                    echo number_format(
                        $order["total"],
                        2
                    );
                ?>

            </td>


            <td>

                <?php
                    echo $order["order_date"];
                ?>

            </td>

        </tr>

<?php endwhile; ?>

    </table>

</div>


<!-- ========================================================
     CRUD EXPLANATION
========================================================= -->

<div class="card">

    <h2>☁️ System Information</h2>

    <p>
        <strong>Create:</strong>
        Add new products to the store.
    </p>

    <p>
        <strong>Read:</strong>
        View and search available products.
    </p>

    <p>
        <strong>Update:</strong>
        Modify product name, category, price and stock.
    </p>

    <p>
        <strong>Delete:</strong>
        Remove products from the database.
    </p>

    <p>
        <strong>Purchase:</strong>
        Purchase products and automatically reduce inventory.
    </p>

</div>


</div>

</body>

</html>
PHP


# ============================================================
# 8. SET PERMISSIONS
# ============================================================

chown -R apache:apache /var/www/html

chmod 644 /var/www/html/*.php


# ============================================================
# 9. MAKE PHP THE DEFAULT INDEX
# ============================================================

sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/' \
    /etc/httpd/conf/httpd.conf


# ============================================================
# 10. RESTART APACHE
# ============================================================

systemctl restart httpd


# ============================================================
# 11. TEST DATABASE
# ============================================================

echo "Testing database..."

mariadb -u ecomuser -pecompassword ecommerce \
    -e "SELECT COUNT(*) AS product_count FROM products;"


# ============================================================
# 12. CREATE DEPLOYMENT LOG
# ============================================================

cat > /var/www/html/deployment.txt <<EOF

===========================================
TechMart E-Commerce System
===========================================

Operating System:
Amazon Linux 2023

Web Server:
Apache HTTP Server

Programming Language:
PHP

Database:
MariaDB

CRUD:
CREATE
READ
UPDATE
DELETE

Purchase:
YES

Sample Products:
Phones
Tablets
Laptops
Audio
Accessories

Deployment Date:
$(date)

===========================================

EOF


echo "=========================================="
echo " E-COMMERCE SYSTEM DEPLOYMENT COMPLETE"
echo "=========================================="
echo ""
echo "Apache: RUNNING"
echo "PHP: INSTALLED"
echo "MariaDB: RUNNING"
echo "Database: ecommerce"
echo "CRUD: ENABLED"
echo "Purchase System: ENABLED"
echo ""
echo "Open:"
echo "http://YOUR-EC2-PUBLIC-IP"
echo "=========================================="
