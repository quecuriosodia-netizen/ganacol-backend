const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// conexión a MySQL
const mysql = require('mysql2');

const db = mysql.createConnection({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});

db.connect((err) => {
  if (err) {
    console.log("❌ Error MySQL:", err);
  } else {
    console.log("✅ MySQL conectado");
  }
});

// ==============================
// REGISTER (AHORA PENDIENTE)
// ==============================
app.post('/register', (req, res) => {
    const { nombre, email, telefono, password, sponsor_id } = req.body;

    db.query(
        'INSERT INTO users (codigo, nombre, email, telefono, password, sponsor_id, estado) VALUES (NULL, ?, ?, ?, ?, ?, "pendiente")',
        [nombre, email, telefono, password, sponsor_id],
        (err) => {
            if (err) return res.send(err);

            res.send({
                message: 'Usuario registrado, pendiente de activación'
            });
        }
    );
});

// ==============================
// LOGIN
// ==============================
app.post('/login', (req, res) => {
    const { email, password } = req.body;

    db.query(
        'SELECT * FROM users WHERE email = ? AND password = ?',
        [email, password],
        (err, results) => {
            if (err) return res.status(500).send('Error en el servidor');

            if (results.length > 0) {
                res.json({
                    success: true,
                    user: results[0]
                });
            } else {
                res.json({
                    success: false,
                    message: 'Credenciales incorrectas'
                });
            }
        }
    );
});

// ==============================
// USUARIOS
// ==============================
app.get('/users', (req, res) => {
    db.query('SELECT * FROM users', (err, result) => {
        if (err) return res.send(err);
        res.send(result);
    });
});

// ==============================
// ACTIVAR (AQUÍ PASA TODO 🔥)
// ==============================
app.post('/activate/:id', (req, res) => {
    const userId = req.params.id;

    // generar código
    db.query('SELECT MAX(codigo) AS maxCodigo FROM users', (err, resultCodigo) => {
        if (err) return res.send(err);

        let nuevoCodigo = resultCodigo[0].maxCodigo ? resultCodigo[0].maxCodigo + 1 : 501;

        // activar usuario
        db.query(
            "UPDATE users SET estado = 'activo', codigo = ? WHERE id = ?",
            [nuevoCodigo, userId],
            (err) => {
                if (err) return res.send(err);

                // obtener sponsor
                db.query(
                    'SELECT sponsor_id FROM users WHERE id = ?',
                    [userId],
                    (err, userData) => {
                        if (err) return res.send(err);

                        const sponsor_id = userData[0].sponsor_id;

                        // contar posición SOLO activos
                        db.query(
                            'SELECT COUNT(*) AS total FROM users WHERE sponsor_id = ? AND estado = "activo"',
                            [sponsor_id],
                            (err, countResult) => {
                                if (err) return res.send(err);

                                const numero = countResult[0].total;

                                // sponsor del sponsor
                                db.query(
                                    'SELECT sponsor_id FROM users WHERE id = ?',
                                    [sponsor_id],
                                    (err, sponsorData) => {
                                        if (err) return res.send(err);

                                        const sponsorDelSponsor = sponsorData[0]?.sponsor_id || null;

                                        let beneficiario;

                                        if ([1,4,7,10].includes(numero)) {
                                            beneficiario = sponsorDelSponsor;
                                        } else {
                                            beneficiario = sponsor_id;
                                        }

                                        // comisión nivel 1
                                        db.query(
                                            'INSERT INTO commissions (from_user_id, to_user_id, monto, nivel) VALUES (?, ?, 10, 1)',
                                            [userId, beneficiario]
                                        );

                                        // comisión nivel 2
                                        if (sponsorDelSponsor && [1,4,7,10].includes(numero)) {
                                            db.query(
                                                'INSERT INTO commissions (from_user_id, to_user_id, monto, nivel) VALUES (?, ?, 10, 2)',
                                                [userId, sponsorDelSponsor]
                                            );
                                        }

                                        res.send({
                                            message: 'Usuario activado correctamente',
                                            codigo: nuevoCodigo
                                        });
                                    }
                                );
                            }
                        );
                    }
                );
            }
        );
    });
});

// ==============================
// DESACTIVAR (MOVER RED 🔥)
// ==============================
app.post('/deactivate/:id', (req, res) => {
    const userId = req.params.id;

    // obtener sponsor
    db.query(
        'SELECT sponsor_id FROM users WHERE id = ?',
        [userId],
        (err, result) => {
            if (err) return res.send(err);

            const sponsor = result[0].sponsor_id;

            // mover hijos al sponsor
            db.query(
                'UPDATE users SET sponsor_id = ? WHERE sponsor_id = ?',
                [sponsor, userId],
                (err) => {
                    if (err) return res.send(err);

                    // desactivar
                    db.query(
                        "UPDATE users SET estado = 'inactivo' WHERE id = ?",
                        [userId],
                        (err) => {
                            if (err) return res.send(err);

                            res.send({
                                message: 'Usuario desactivado y red reasignada'
                            });
                        }
                    );
                }
            );
        }
    );
});

// ==============================
// COMISIONES
// ==============================
app.get('/commissions', (req, res) => {
    db.query('SELECT * FROM commissions', (err, result) => {
        if (err) return res.send(err);
        res.send(result);
    });
});

app.get('/my-commissions/:id', (req, res) => {
    db.query(
        'SELECT * FROM commissions WHERE to_user_id = ?',
        [req.params.id],
        (err, result) => {
            if (err) return res.send(err);
            res.send(result);
        }
    );
});

app.get('/my-total/:id', (req, res) => {
    db.query(
        'SELECT SUM(monto) as total FROM commissions WHERE to_user_id = ?',
        [req.params.id],
        (err, result) => {
            if (err) return res.send(err);
            res.send(result[0]);
        }
    );
});

// ==============================
// RED
// ==============================
app.get('/my-network/:id', (req, res) => {
    const userId = req.params.id;

    db.query(
        'SELECT id, codigo, nombre, estado FROM users WHERE sponsor_id = ?',
        [userId],
        (err, directos) => {
            if (err) return res.send(err);

            db.query(
                `SELECT id, codigo, nombre, estado 
                 FROM users 
                 WHERE sponsor_id IN (SELECT id FROM users WHERE sponsor_id = ?)`,
                [userId],
                (err, indirectos) => {
                    if (err) return res.send(err);

                    res.send({ directos, indirectos });
                }
            );
        }
    );
});

// ==============================
// PLAN
// ==============================
app.get('/my-plan/:id', (req, res) => {
    const userId = req.params.id;

    db.query(
        `SELECT COUNT(*) as total 
         FROM users 
         WHERE sponsor_id = ? 
         OR sponsor_id IN (SELECT id FROM users WHERE sponsor_id = ?)`,
        [userId, userId],
        (err, result) => {
            if (err) return res.send(err);

            const total = result[0].total;

            let pago = 10;
            if (total >= 6) pago = 20;
            if (total >= 12) pago = 40;

            res.send({ total_personas: total, pago_mensual: pago });
        }
    );
});

// ==============================
// SERVIDOR
// ==============================
app.listen(3000, () => {
    console.log('Servidor corriendo en puerto 3000');
});