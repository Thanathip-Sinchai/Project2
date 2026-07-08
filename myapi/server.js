// server.js
const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const path = require("path");
const fs = require("fs");
const multer = require("multer");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const http = require("http"); // ✅ เพิ่ม http เข้ามา

const app = express();

// =====================
// Config
// =====================
const JWT_SECRET = process.env.JWT_SECRET || "CHANGE_THIS_SECRET_123456789";
const JWT_EXPIRES_IN = "7d";

// =====================
// Middleware
// =====================
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "X-Shop-Id"],
  })
);

// -------------------------------------------------------
// 🐍 PYTHON PROXY (ทางผ่านไปหา Python Port 8000)
// -------------------------------------------------------
const proxyToPython = (req, res) => {
  console.log(`🔄 Proxying ${req.method} ${req.originalUrl} -> Python (8000)`);
  
  const options = {
    hostname: '127.0.0.1', 
    port: 8000,            
    path: req.originalUrl, 
    method: req.method,
    headers: req.headers,
  };

  const proxyReq = http.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (e) => {
    console.error("❌ Python Proxy Error:", e.message);
    res.status(502).json({ error: "Cannot connect to Python OCR server (Is it running on port 8000?)" });
  });

  req.pipe(proxyReq, { end: true });
};

app.use('/ocr', proxyToPython);      
app.use('/predict', proxyToPython); 
app.use('/process', proxyToPython);

app.use(express.json());

// =====================
// Uploads folder + static serve
// =====================
const UPLOAD_DIR = path.join(__dirname, "uploads");
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}
app.use("/uploads", express.static(UPLOAD_DIR));

// =====================
// Multer config
// =====================
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || "").toLowerCase() || ".jpg";
    const safeExt = [".jpg", ".jpeg", ".png", ".webp"].includes(ext) ? ext : ".jpg";
    const name = `img_${Date.now()}_${Math.floor(Math.random() * 1e9)}${safeExt}`;
    cb(null, name);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    console.log("📥 Incoming file type:", file.mimetype);
    const allowedTypes = [
      "image/jpeg",
      "image/jpg",
      "image/png",
      "image/webp",
      "application/octet-stream",
    ];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      console.warn("⚠️ Warning: Unknown file type uploaded:", file.mimetype);
      cb(null, true);
    }
  },
});

const shopStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || "").toLowerCase() || ".jpg";
    const safeExt = [".jpg", ".jpeg", ".png", ".webp"].includes(ext) ? ext : ".jpg";
    const name = `shop_${Date.now()}_${Math.floor(Math.random() * 1e9)}${safeExt}`;
    cb(null, name);
  },
});
const uploadShop = multer({
  storage: shopStorage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    console.log("🏪 Incoming shop image type:", file.mimetype);
    cb(null, true);
  },
});

// =====================
// MySQL Connection
// =====================
const db = mysql.createPool({
  host: "localhost",
  user: "root",
  password: process.env.MYSQL_PASSWORD || "0801467086",
  database: "smart_warehouse",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});
const dbp = db.promise();

// =====================
// Helpers
// =====================
function isValidEmail(email) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(email || "").trim());
}

function normalizeProductionDate(productionDate) {
  if (!productionDate) return null;
  return typeof productionDate === "string" && productionDate.includes("T")
    ? productionDate.split("T")[0]
    : productionDate;
}

function normalizeNameKey(name) {
  if (!name) return "";
  return String(name)
    .normalize("NFKC")
    .replace(/[\u200B-\u200D\uFEFF]/g, "") 
    .trim()
    .replace(/\s+/g, " ")
    .replace(/[\u0E48-\u0E4B]/g, ""); 
}

function normalizeBarcode(raw) {
  let digits = String(raw || "").replace(/[^0-9]/g, "");
  if (digits.length >= 12 && digits.startsWith("0")) {
    digits = digits.replace(/^0+/, "");
  }
  if (digits.length >= 8 && digits.length <= 13 && digits.startsWith("1")) {
    digits = digits.substring(1);
  }
  return digits;
}

// =====================
// Auth Middleware
// =====================
function authRequired(req, res, next) {
  try {
    const auth = req.headers.authorization || "";
    const [type, token] = auth.split(" ");
    if (type !== "Bearer" || !token) {
      return res.status(401).json({ error: "Missing or invalid Authorization header" });
    }
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (e) {
    return res.status(401).json({ error: "Unauthorized" });
  }
}

// =====================
// Shop Middleware
// =====================
function shopRequired(req, res, next) {
  try {
    const shopId = Number(req.headers["x-shop-id"]);
    if (!shopId) return res.status(400).json({ error: "Missing X-Shop-Id" });
    req.shopId = shopId;
    next();
  } catch (e) {
    return res.status(400).json({ error: "Invalid X-Shop-Id" });
  }
}

async function loadShopRole(req, res, next) {
  try {
    const [rows] = await dbp.query(
      "SELECT role FROM shop_members WHERE shop_id=? AND user_id=? LIMIT 1",
      [req.shopId, req.user.id]
    );
    if (rows.length === 0) return res.status(403).json({ error: "Not a member of this shop" });
    req.shopRole = rows[0].role; 
    next();
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}

function allowShopRoles(...roles) {
  const allowed = roles.map((r) => String(r).toLowerCase());
  return (req, res, next) => {
    const role = String(req.shopRole || "").toLowerCase();
    if (!allowed.includes(role)) return res.status(403).json({ error: "Forbidden (shop role)" });
    next();
  };
}

// =====================
// Stock History helper
// =====================
async function insertStockHistory(conn, row) {
  await conn.query(
    `INSERT INTO stock_history
      (shop_id, action, product_id, product_name, barcode, qty, before_qty, after_qty, note, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      row.shop_id,
      row.action,
      row.product_id ?? null,
      row.product_name ?? null,
      row.barcode,
      Number(row.qty || 0),
      Number(row.before_qty || 0),
      Number(row.after_qty || 0),
      row.note ?? null,
      row.created_by ?? null,
    ]
  );
}

// =====================
// ROUTES: Auth
// =====================
app.post("/auth/register", async (req, res) => {
  try {
    const body = req.body || {};
    const username = (body.username ?? body.name ?? "").toString().trim();
    const email = (body.email ?? "").toString().trim().toLowerCase();
    const password = (body.password ?? "").toString();
    const confirmPassword = (body.confirmPassword ?? body.confirm ?? "").toString();

    if (!username || !email || !password) return res.status(400).json({ error: "Missing fields" });
    if (!isValidEmail(email)) return res.status(400).json({ error: "Invalid email" });
    if (confirmPassword && password !== confirmPassword) {
      return res.status(400).json({ error: "Password mismatch" });
    }
    if (password.length < 6) return res.status(400).json({ error: "Password too short" });

    const [dup] = await dbp.query("SELECT id FROM users WHERE email=? OR username=? LIMIT 1", [
      email,
      username,
    ]);
    if (dup.length > 0) return res.status(409).json({ error: "Already exists" });

    const password_hash = await bcrypt.hash(password, 10);
    const [result] = await dbp.query(
      "INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)",
      [username, email, password_hash]
    );

    return res
      .status(201)
      .json({ message: "✅ Registered", user: { id: result.insertId, username, email } });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

app.post("/auth/login", async (req, res) => {
  try {
    const { emailOrUsername, password } = req.body;
    if (!emailOrUsername || !password) return res.status(400).json({ error: "Missing fields" });

    const [rows] = await dbp.query("SELECT * FROM users WHERE email=? OR username=? LIMIT 1", [
      String(emailOrUsername || "").toLowerCase(),
      emailOrUsername,
    ]);
    if (rows.length === 0) return res.status(401).json({ error: "Invalid credentials" });

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: "Invalid credentials" });

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role || "Owner" },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    return res.json({
      access_token: token,
      user: { id: user.id, username: user.username, email: user.email, avatar_url: user.avatar_url },
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// =====================
// ROUTES: Profile
// =====================
app.get("/me", authRequired, async (req, res) => {
  try {
    const [rows] = await dbp.query(
      "SELECT id, username, email, role, avatar_url FROM users WHERE id=? LIMIT 1",
      [req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: "Not found" });
    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

app.put("/me", authRequired, async (req, res) => {
  try {
    const userId = req.user.id;
    const { username, email } = req.body;
    await dbp.query("UPDATE users SET username=?, email=? WHERE id=?", [username, email, userId]);
    return res.json({ message: "✅ Profile updated" });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

app.put("/me/avatar", authRequired, upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "Missing file" });
    const imagePath = `/uploads/${req.file.filename}`;
    await dbp.query("UPDATE users SET avatar_url=? WHERE id=?", [imagePath, req.user.id]);
    return res.json({ message: "✅ Avatar updated", avatar_url: imagePath });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// =====================
// ROUTES: Shops
// =====================
app.get("/shops", authRequired, async (req, res) => {
  try {
    const [rows] = await dbp.query(
      `SELECT s.shop_id, s.shop_name, s.shop_image, sm.role AS my_role
       FROM shop_members sm
       JOIN shops s ON s.shop_id = sm.shop_id
       WHERE sm.user_id = ?
       ORDER BY s.shop_id DESC`,
      [req.user.id]
    );
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

app.post("/shops", authRequired, async (req, res) => {
  try {
    const shop_name = String(req.body?.shop_name || "").trim();
    if (!shop_name) return res.status(400).json({ error: "Missing shop_name" });

    const [r1] = await dbp.query("INSERT INTO shops (shop_name, created_by) VALUES (?, ?)", [
      shop_name,
      req.user.id,
    ]);

    const shopId = r1.insertId;

    await dbp.query("INSERT INTO shop_members (shop_id, user_id, role) VALUES (?, ?, 'owner')", [
      shopId,
      req.user.id,
    ]);

    return res.status(201).json({
      message: "✅ Shop created",
      shop: { shop_id: shopId, shop_name, my_role: "owner", shop_image: null },
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

app.put("/shops/:shopId", authRequired, async (req, res) => {
  try {
    const shopId = Number(req.params.shopId);
    const shop_name = String(req.body?.shop_name || req.body?.shopName || "").trim();

    if (!shopId) return res.status(400).json({ error: "Invalid shopId" });
    if (!shop_name) return res.status(400).json({ error: "Missing shop_name" });

    const [rows] = await dbp.query(
      "SELECT role FROM shop_members WHERE shop_id=? AND user_id=? LIMIT 1",
      [shopId, req.user.id]
    );
    if (rows.length === 0) return res.status(403).json({ error: "Not a member of this shop" });
    if (String(rows[0].role || "").toLowerCase() !== "owner") {
      return res.status(403).json({ error: "ONLY_OWNER_CAN_EDIT_SHOP_NAME" });
    }

    const [r] = await dbp.query("UPDATE shops SET shop_name=? WHERE shop_id=?", [shop_name, shopId]);
    if (r.affectedRows === 0) return res.status(404).json({ error: "Shop not found" });

    return res.json({ message: "✅ Shop name updated", shop_id: shopId, shop_name });
  } catch (e) {
    console.error("Update shop name error:", e);
    return res.status(500).json({ error: e.message });
  }
});

app.put("/shops/:shopId/avatar", authRequired, uploadShop.single("image"), async (req, res) => {
  try {
    const shopId = Number(req.params.shopId);
    if (!shopId) return res.status(400).json({ error: "Invalid shopId" });

    if (!req.file) return res.status(400).json({ error: "Missing file" });

    const [rows] = await dbp.query(
      "SELECT role FROM shop_members WHERE shop_id=? AND user_id=? LIMIT 1",
      [shopId, req.user.id]
    );
    if (rows.length === 0) return res.status(403).json({ error: "Not a member of this shop" });

    const role = String(rows[0].role || "").toLowerCase();
    if (role !== "owner") return res.status(403).json({ error: "ONLY_OWNER_CAN_EDIT_SHOP_IMAGE" });

    const imagePath = `/uploads/${req.file.filename}`;
    await dbp.query("UPDATE shops SET shop_image=? WHERE shop_id=?", [imagePath, shopId]);

    return res.json({ message: "✅ Shop image updated", shop_id: shopId, shop_image: imagePath });
  } catch (e) {
    console.error("Update shop avatar error:", e);
    return res.status(500).json({ error: e.message });
  }
});

app.get(
  "/users/search",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager"),
  async (req, res) => {
    try {
      const q = String(req.query.q || "").trim();
      if (!q || q.length < 2) return res.json([]);

      const like = `%${q}%`;
      const [rows] = await dbp.query(
        `SELECT id, username, email
         FROM users
         WHERE username LIKE ? OR email LIKE ?
         ORDER BY id DESC
         LIMIT 30`,
        [like, like]
      );

      return res.json(rows);
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

app.get(
  "/shop/members",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager"),
  async (req, res) => {
    try {
      const [rows] = await dbp.query(
        `SELECT u.id, u.username, u.email, sm.role
         FROM shop_members sm
         JOIN users u ON u.id = sm.user_id
         WHERE sm.shop_id = ?
         ORDER BY u.id DESC`,
        [req.shopId]
      );
      return res.json(rows);
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

app.post(
  "/shop/members",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner"),
  async (req, res) => {
    try {
      const user_id = Number(req.body?.user_id);
      const role = String(req.body?.role || "employee").toLowerCase();

      if (!user_id) return res.status(400).json({ error: "Missing user_id" });
      if (!["manager", "employee", "owner"].includes(role))
        return res.status(400).json({ error: "Invalid role" });

      const [u] = await dbp.query("SELECT id FROM users WHERE id=? LIMIT 1", [user_id]);
      if (u.length === 0) return res.status(404).json({ error: "User not found" });

      await dbp.query("INSERT INTO shop_members (shop_id, user_id, role) VALUES (?, ?, ?)", [
        req.shopId,
        user_id,
        role,
      ]);

      return res.status(201).json({ message: "✅ member added" });
    } catch (e) {
      if (String(e.message || "").includes("Duplicate"))
        return res.status(409).json({ error: "User already in this shop" });
      return res.status(500).json({ error: e.message });
    }
  }
);

app.put(
  "/shop/members/:userId/role",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner"),
  async (req, res) => {
    try {
      const userId = Number(req.params.userId);
      const role = String(req.body?.role || "").toLowerCase();
      if (!userId) return res.status(400).json({ error: "Invalid userId" });
      if (!["owner", "manager", "employee"].includes(role))
        return res.status(400).json({ error: "Invalid role" });

      if (userId === Number(req.user.id) && role !== "owner") {
        return res.status(400).json({ error: "Cannot downgrade your own owner role" });
      }

      const [r] = await dbp.query("UPDATE shop_members SET role=? WHERE shop_id=? AND user_id=?", [
        role,
        req.shopId,
        userId,
      ]);
      if (r.affectedRows === 0) return res.status(404).json({ error: "Member not found" });

      return res.json({ message: "✅ role updated" });
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

app.delete(
  "/shop/members/:userId",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner"),
  async (req, res) => {
    try {
      const userId = Number(req.params.userId);
      if (!userId) return res.status(400).json({ error: "Invalid userId" });

      if (userId === Number(req.user.id)) return res.status(400).json({ error: "Cannot remove yourself" });

      const [r] = await dbp.query("DELETE FROM shop_members WHERE shop_id=? AND user_id=?", [
        req.shopId,
        userId,
      ]);
      if (r.affectedRows === 0) return res.status(404).json({ error: "Member not found" });

      return res.json({ message: "✅ member removed" });
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

// =====================
// ✅ PRODUCTS (shop-scoped) 
// ✅ เพิ่มการ JOIN หา total_in / total_out
// =====================

app.post(
  "/products/fix-names",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager"),
  async (req, res) => {
    try {
      const shopId = req.shopId;
      const [rows] = await dbp.query("SELECT product_id, product_name FROM products WHERE shop_id=?", [shopId]);
      let changed = 0;

      const conn = await dbp.getConnection();
      try {
        await conn.beginTransaction();
        for (const r of rows) {
          const normalized = normalizeNameKey(r.product_name);
          if (normalized && normalized !== String(r.product_name || "")) {
            await conn.query("UPDATE products SET product_name=? WHERE product_id=? AND shop_id=?", [
              normalized,
              r.product_id,
              shopId,
            ]);
            changed++;
          }
        }
        await conn.commit();
      } catch (e) {
        await conn.rollback();
        throw e;
      } finally {
        conn.release();
      }

      return res.json({ message: "✅ fixed names", changed });
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

app.get(
  "/products/summary",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager", "employee"),
  async (req, res) => {
    try {
      const shopId = req.shopId;

      // ✅ อัปเดต SQL ดึงยอด IN/OUT จากตาราง History
      const [products] = await dbp.query(`
        SELECT 
          p.product_id,
          p.product_name, 
          p.quantity,
          COALESCE(SUM(CASE WHEN h.action = 'IN' THEN h.qty ELSE 0 END), 0) AS total_in,
          COALESCE(SUM(CASE WHEN h.action = 'OUT' THEN h.qty ELSE 0 END), 0) AS total_out
        FROM products p
        LEFT JOIN stock_history h ON p.product_id = h.product_id
        WHERE p.shop_id=?
        GROUP BY p.product_id
      `, [shopId]);
      
      const [groups] = await dbp.query("SELECT product_name, group_image FROM product_groups WHERE shop_id=?", [shopId]);

      const groupImages = {};
      for (const g of groups) {
        const key = normalizeNameKey(g.product_name);
        groupImages[key] = g.group_image;
      }

      const summaryMap = {};
      for (const p of products) {
        const key = normalizeNameKey(p.product_name);

        if (!summaryMap[key]) {
          summaryMap[key] = {
            product_name: key,
            lots_count: 0,
            total_quantity: 0,
            total_in: 0,
            total_out: 0,
            group_image: groupImages[key] || null,
          };
        }

        summaryMap[key].lots_count += 1;
        summaryMap[key].total_quantity += Number(p.quantity) || 0;
        summaryMap[key].total_in += Number(p.total_in) || 0;
        summaryMap[key].total_out += Number(p.total_out) || 0;
      }

      const result = Object.values(summaryMap).sort((a, b) => a.product_name.localeCompare(b.product_name, "th"));
      return res.json(result);
    } catch (e) {
      console.error("Summary error:", e);
      return res.status(500).json({ error: e.message });
    }
  }
);

app.put(
  "/products/group-image",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager"),
  upload.single("image"),
  async (req, res) => {
    try {
      const shopId = req.shopId;
      const product_name = normalizeNameKey(req.body.product_name || "");
      if (!product_name) return res.status(400).json({ error: "Missing product_name" });
      if (!req.file) return res.status(400).json({ error: "Missing file" });

      const imagePath = `/uploads/${req.file.filename}`;

      await dbp.query(
        `INSERT INTO product_groups (shop_id, product_name, group_image)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE group_image=VALUES(group_image)`,
        [shopId, product_name, imagePath]
      );

      return res.json({ message: "✅ Group image updated", group_image: imagePath });
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

app.get(
  "/products",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager", "employee"),
  async (req, res) => {
    try {
      const shopId = req.shopId;
      const name = normalizeNameKey(req.query.name || "");

      // ✅ อัปเดต SQL ดึงยอด IN/OUT มาให้หน้ารายการย่อยใช้งาน
      const sql = `
        SELECT 
          p.*,
          COALESCE(SUM(CASE WHEN h.action = 'IN' THEN h.qty ELSE 0 END), 0) AS total_in,
          COALESCE(SUM(CASE WHEN h.action = 'OUT' THEN h.qty ELSE 0 END), 0) AS total_out
        FROM products p
        LEFT JOIN stock_history h ON p.product_id = h.product_id
        WHERE p.shop_id=?
        GROUP BY p.product_id
        ORDER BY p.product_id DESC
      `;
      
      const [all] = await dbp.query(sql, [shopId]);

      if (name) {
        const filtered = all.filter((p) => normalizeNameKey(p.product_name) === name);
        return res.json(filtered);
      }

      return res.json(all);
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

app.post(
  "/products",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager", "employee"),
  upload.single("image"),
  async (req, res) => {
    const shopId = req.shopId;

    try {
      let { product_name, barcode, size, unit_price, quantity, productionDate } = req.body;

      product_name = normalizeNameKey(product_name);
      barcode = normalizeBarcode(barcode);

      const qtyNum = Number(quantity || 0);
      const priceNum = Number(unit_price || 0);

      if (!product_name) return res.status(400).json({ error: "Missing product_name" });
      if (!barcode) return res.status(400).json({ error: "Missing barcode" });
      if (!Number.isFinite(qtyNum) || qtyNum < 0) return res.status(400).json({ error: "Invalid quantity" });
      if (!Number.isFinite(priceNum) || priceNum < 0) return res.status(400).json({ error: "Invalid unit_price" });

      const imagePath = req.file ? `/uploads/${req.file.filename}` : null;

      const conn = await dbp.getConnection();
      try {
        await conn.beginTransaction();

        const [result] = await conn.query(
          `INSERT INTO products
            (shop_id, product_name, barcode, size, unit_price, quantity, productionDate, product_image)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [shopId, product_name, barcode, size || null, priceNum, qtyNum, normalizeProductionDate(productionDate), imagePath]
        );

        const newId = result.insertId;

        // ✅ บันทึกประวัติ "IN" ตอนสร้างสินค้าแรกเริ่ม เพื่อให้ total_in ทำงานได้ตรงเป๊ะ
        await insertStockHistory(conn, {
          shop_id: shopId,
          action: "IN",
          product_id: newId,
          product_name: product_name,
          barcode: barcode,
          qty: qtyNum,
          before_qty: 0,
          after_qty: qtyNum,
          note: "CREATE_PRODUCT",
          created_by: req.user.id,
        });

        await conn.commit();
        return res.status(201).json({ message: "✅ Product created", id: newId, product_image: imagePath });
      } catch (e) {
        await conn.rollback();
        console.error("Create product (tx) error:", e);
        return res.status(500).json({ error: e.message });
      } finally {
        conn.release();
      }
    } catch (e) {
      console.error("Create product error:", e);
      return res.status(500).json({ error: e.message });
    }
  }
);

app.put(
  "/products/:id",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager"),
  upload.single("image"),
  async (req, res) => {
    try {
      const shopId = req.shopId;
      const { id } = req.params;

      let { product_name, barcode, size, unit_price, quantity, productionDate } = req.body;

      product_name = normalizeNameKey(product_name);
      barcode = normalizeBarcode(barcode);
      const newImage = req.file ? `/uploads/${req.file.filename}` : null;

      const [exists] = await dbp.query(
        "SELECT product_id, product_image FROM products WHERE product_id=? AND shop_id=? LIMIT 1",
        [id, shopId]
      );
      if (exists.length === 0) return res.status(404).json({ error: "Not found" });

      let sql =
        "UPDATE products SET product_name=?, barcode=?, size=?, unit_price=?, quantity=?, productionDate=? WHERE product_id=? AND shop_id=?";
      let params = [product_name, barcode, size || null, unit_price, quantity, normalizeProductionDate(productionDate), id, shopId];

      if (newImage) {
        sql =
          "UPDATE products SET product_name=?, barcode=?, size=?, unit_price=?, quantity=?, productionDate=?, product_image=? WHERE product_id=? AND shop_id=?";
        params = [product_name, barcode, size || null, unit_price, quantity, normalizeProductionDate(productionDate), newImage, id, shopId];
      }

      await dbp.query(sql, params);
      return res.json({ message: "✅ Product updated", product_image: newImage || exists[0]?.product_image || null });
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

app.delete(
  "/products/:id",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager"),
  async (req, res) => {
    try {
      const shopId = req.shopId;
      const id = Number(req.params.id);

      const [r] = await dbp.query("DELETE FROM products WHERE product_id=? AND shop_id=?", [id, shopId]);
      if (r.affectedRows === 0) return res.status(404).json({ error: "Not found" });

      return res.json({ message: "✅ Product deleted" });
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

// =====================
// ✅ STOCK IN/OUT
// =====================
app.post(
  "/stock/in",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager", "employee"),
  async (req, res) => {
    const shopId = req.shopId;

    try {
      let { barcode, qty, note } = req.body;
      barcode = normalizeBarcode(barcode);
      qty = Number(qty || 0);
      note = String(note || "").trim();

      if (!barcode) return res.status(400).json({ error: "Missing barcode" });
      if (!qty || qty <= 0) return res.status(400).json({ error: "Invalid qty" });

      const conn = await dbp.getConnection();
      try {
        await conn.beginTransaction();

        const [rows] = await conn.query(
          `SELECT product_id, product_name, barcode, quantity
           FROM products
           WHERE shop_id=? AND barcode=?
           ORDER BY product_id DESC
           LIMIT 1`,
          [shopId, barcode]
        );
        if (rows.length === 0) throw new Error("Not found");

        const p = rows[0];
        const beforeQty = Number(p.quantity || 0);
        const afterQty = beforeQty + qty;

        await conn.query("UPDATE products SET quantity=? WHERE product_id=? AND shop_id=?", [
          afterQty,
          p.product_id,
          shopId,
        ]);

        await insertStockHistory(conn, {
          shop_id: shopId,
          action: "IN",
          product_id: p.product_id,
          product_name: p.product_name,
          barcode: p.barcode,
          qty,
          before_qty: beforeQty,
          after_qty: afterQty,
          note: note || null,
          created_by: req.user.id,
        });

        await conn.commit();
        return res.json({
          message: "✅ stockIn ok",
          barcode: p.barcode,
          before_quantity: beforeQty,
          total_quantity: afterQty,
        });
      } catch (e) {
        await conn.rollback();
        return res.status(400).json({ error: e.message });
      } finally {
        conn.release();
      }
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

app.post(
  "/stock/out",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager", "employee"),
  async (req, res) => {
    const shopId = req.shopId;

    try {
      let { barcode, qty, note } = req.body;
      barcode = normalizeBarcode(barcode);
      qty = Number(qty || 0);
      note = String(note || "").trim();

      if (!barcode) return res.status(400).json({ error: "Missing barcode" });
      if (!qty || qty <= 0) return res.status(400).json({ error: "Invalid qty" });

      const conn = await dbp.getConnection();
      try {
        await conn.beginTransaction();

        const [rows] = await conn.query(
          `SELECT product_id, product_name, barcode, quantity
           FROM products
           WHERE shop_id=? AND barcode=?
           ORDER BY product_id DESC
           LIMIT 1`,
          [shopId, barcode]
        );
        if (rows.length === 0) throw new Error("Not found");

        const p = rows[0];
        const beforeQty = Number(p.quantity || 0);
        if (beforeQty < qty) throw new Error("Not enough stock");

        const afterQty = beforeQty - qty;

        await conn.query("UPDATE products SET quantity=? WHERE product_id=? AND shop_id=?", [
          afterQty,
          p.product_id,
          shopId,
        ]);

        await insertStockHistory(conn, {
          shop_id: shopId,
          action: "OUT",
          product_id: p.product_id,
          product_name: p.product_name,
          barcode: p.barcode,
          qty,
          before_qty: beforeQty,
          after_qty: afterQty,
          note: note || null,
          created_by: req.user.id,
        });

        await conn.commit();
        return res.json({
          message: "✅ stockOut ok",
          barcode: p.barcode,
          before_quantity: beforeQty,
          total_quantity: afterQty,
        });
      } catch (e) {
        await conn.rollback();
        return res.status(400).json({ error: e.message });
      } finally {
        conn.release();
      }
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

// =====================
// ✅ STOCK HISTORY
// =====================
app.get(
  "/stock/history",
  authRequired,
  shopRequired,
  loadShopRole,
  allowShopRoles("owner", "manager", "employee"),
  async (req, res) => {
    try {
      const shopId = req.shopId;
      const range = String(req.query.range || "7d").toLowerCase();
      const q = String(req.query.q || "").trim();

      let where = "shop_id=?";
      const params = [shopId];

      if (range !== "all") {
        let days = 7;
        if (range === "today") days = 0;
        if (range === "30d") days = 30;

        if (days === 0) where += " AND created_at >= CURDATE()";
        else {
          where += " AND created_at >= (NOW() - INTERVAL ? DAY)";
          params.push(days);
        }
      }

      if (q) {
        const like = `%${q}%`;
        where += " AND (barcode LIKE ? OR product_name LIKE ? OR action LIKE ? OR note LIKE ?)";
        params.push(like, like, like, like);
      }

      const [rows] = await dbp.query(
        `SELECT history_id, action, product_id, product_name, barcode, qty, before_qty, after_qty, note, created_by, created_at
         FROM stock_history
         WHERE ${where}
         ORDER BY created_at DESC
         LIMIT 300`,
        params
      );

      return res.json(rows);
    } catch (e) {
      return res.status(500).json({ error: e.message });
    }
  }
);

// =====================
// Start Server
// =====================
const PORT = process.env.PORT || 3000;
const HOST = "0.0.0.0";

app.listen(PORT, HOST, () => {
  console.log(`🚀 Server running on http://${HOST}:${PORT}`);
  console.log("📂 Serving uploads from:", UPLOAD_DIR);
  console.log("🐍 Python Proxy enabled (forwarding /ocr -> port 8000)");
});