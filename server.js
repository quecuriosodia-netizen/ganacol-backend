const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// conexión a MySQL

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

    // 🔥 VALIDAR MAXIMO 12 DIRECTOS
    db.query(
        'SELECT COUNT(*) AS total FROM users WHERE sponsor_id = ?',
        [sponsor_id],
        (err, result) => {

            if (err) return res.send(err);

            const total = result[0].total;

            if (total >= 12) {
                return res.send({
                    success: false,
                    message: 'Este usuario ya tiene 12 directos'
                });
            }

            // 🔥 REGISTRO
            db.query(
                'INSERT INTO users (codigo, nombre, email, telefono, password, sponsor_id, estado) VALUES (NULL, ?, ?, ?, ?, ?, "pendiente")',
                [nombre, email, telefono, password, sponsor_id],
                (err) => {

                    if (err) return res.send(err);

                    res.send({
                        success: true,
                        message: 'Usuario registrado correctamente'
                    });

                }
            );

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

    // 🔥 VALIDAR SI YA ESTÁ ACTIVO
    db.query(
        'SELECT * FROM users WHERE id = ?',
        [userId],
        (err, resultEstado) => {

            if (err) return res.send(err);

            if (resultEstado.length === 0) {
                return res.send({
                    success: false,
                    message: 'Usuario no encontrado'
                });
            }

            // 🔥 SI YA ESTÁ ACTIVO NO HACER NADA
            if (resultEstado[0].estado === 'activo') {

                return res.send({
                    success: false,
                    message: 'Este usuario ya está activo'
                });

            }

            // ======================================
            // GENERAR NUEVO CÓDIGO
            // ======================================

            db.query(
                'SELECT MAX(codigo) AS maxCodigo FROM users',
                (err, resultCodigo) => {

                    if (err) return res.send(err);

                    let nuevoCodigo =
                        resultCodigo[0].maxCodigo
                            ? resultCodigo[0].maxCodigo + 1
                            : 501;

                    // ======================================
                    // ACTIVAR USUARIO
                    // ======================================

                    db.query(
                        "UPDATE users SET estado = 'activo', codigo = ? WHERE id = ?",
                        [nuevoCodigo, userId],
                        (err) => {

                            if (err) return res.send(err);

                            // ======================================
                            // OBTENER SPONSOR
                            // ======================================

                            db.query(
                                'SELECT sponsor_id FROM users WHERE id = ?',
                                [userId],
                                (err, userData) => {

                                    if (err) return res.send(err);

                                    const sponsor_id =
                                        userData[0].sponsor_id;

                                    // ======================================
                                    // CONTAR ACTIVOS DEL SPONSOR
                                    // ======================================

                                    db.query(
                                        'SELECT COUNT(*) AS total FROM users WHERE sponsor_id = ? AND estado = "activo"',
                                        [sponsor_id],
                                        (err, countResult) => {

                                            if (err) return res.send(err);

                                            const numero =
                                                countResult[0].total;

                                            // ======================================
                                            // SPONSOR DEL SPONSOR
                                            // ======================================

                                            db.query(
                                                'SELECT sponsor_id FROM users WHERE id = ?',
                                                [sponsor_id],
                                                (err, sponsorData) => {

                                                    if (err) return res.send(err);

                                                    const sponsorDelSponsor =
                                                        sponsorData[0]?.sponsor_id || null;

                                                    let beneficiario;

                                                    if ([1,4,7,10].includes(numero)) {
                                                        beneficiario = sponsorDelSponsor;
                                                    } else {
                                                        beneficiario = sponsor_id;
                                                    }

                                                    // ======================================
                                                    // COMISIÓN NIVEL 1
                                                    // ======================================

                                                    if (beneficiario) {

                                                        db.query(
                                                            'INSERT INTO commissions (from_user_id, to_user_id, monto, nivel) VALUES (?, ?, 10, 1)',
                                                            [userId, beneficiario]
                                                        );

                                                    }

                                                    // ======================================
                                                    // ALERTAS 10 Y 20
                                                    // ======================================

                                                    db.query(
                                                        `
                                                        SELECT COUNT(*) as total
                                                        FROM users
                                                        WHERE sponsor_id = ?
                                                        OR sponsor_id IN (
                                                            SELECT id FROM users WHERE sponsor_id = ?
                                                        )
                                                        `,
                                                        [sponsor_id, sponsor_id],
                                                        (err, result) => {

                                                            if (err) {
                                                                console.log(err);
                                                            }

                                                            const total =
                                                                result[0].total;

                                                            // 🔥 ALERTA 10
                                                            if (total == 10) {

                                                                db.query(
                                                                    'INSERT INTO alerts (user_id, mensaje) VALUES (?, ?)',
                                                                    [
                                                                        sponsor_id,
                                                                        'Usuario alcanzó 10 personas y debe subir a $53'
                                                                    ]
                                                                );

                                                            }

                                                            // 🔥 ALERTA 20
                                                            if (total == 20) {

                                                                db.query(
                                                                    'INSERT INTO alerts (user_id, mensaje) VALUES (?, ?)',
                                                                    [
                                                                        sponsor_id,
                                                                        'Usuario alcanzó 20 personas y debe subir a $130'
                                                                    ]
                                                                );

                                                            }

                                                            // ======================================
                                                            // RESPUESTA FINAL
                                                            // ======================================

                                                            res.send({
                                                                success: true,
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

                        }
                    );

                }
            );

        }
    );

});

// ==============================
// DESACTIVAR (MOVER RED 🔥)
// ==============================

app.post('/deactivate/:id', (req, res) => {

    const userId = req.params.id;

    // 🔥 OBTENER SPONSOR Y ESTADO
    db.query(
        'SELECT sponsor_id, estado FROM users WHERE id = ?',
        [userId],
        (err, result) => {

            if (err) return res.send(err);

            // 🔥 USUARIO NO EXISTE
            if (result.length === 0) {

                return res.send({
                    success: false,
                    message: 'Usuario no encontrado'
                });

            }

            // 🔥 SI YA ESTÁ INACTIVO
            if (result[0].estado === 'inactivo') {

                return res.send({
                    success: false,
                    message: 'Este usuario ya está inactivo'
                });

            }

            const sponsor = result[0].sponsor_id;

            // 🔥 MOVER RED AL SPONSOR
            db.query(
                'UPDATE users SET sponsor_id = ? WHERE sponsor_id = ?',
                [sponsor, userId],
                (err) => {

                    if (err) return res.send(err);

                    // 🔥 DESACTIVAR USUARIO
                    db.query(
                        "UPDATE users SET estado = 'inactivo' WHERE id = ?",
                        [userId],
                        (err) => {

                            if (err) return res.send(err);

                            res.send({
                                success: true,
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
// ELIMINAR USUARIO 🔥
// ==============================

app.post('/delete-user/:id', (req, res) => {

    const userId = req.params.id;

    const { adminPassword } = req.body;

    // 🔥 VALIDAR CLAVE ADMIN
    if (adminPassword !== '123456') {

        return res.send({
            success: false,
            message: 'Clave incorrecta'
        });

    }

    // 🔥 OBTENER SPONSOR
    db.query(
        'SELECT sponsor_id FROM users WHERE id = ?',
        [userId],
        (err, result) => {

            if (err) return res.send(err);

            if (result.length === 0) {

                return res.send({
                    success: false,
                    message: 'Usuario no encontrado'
                });

            }

            const sponsor = result[0].sponsor_id;

            // 🔥 MOVER RED AL SPONSOR
            db.query(
                'UPDATE users SET sponsor_id = ? WHERE sponsor_id = ?',
                [sponsor, userId],
                (err) => {

                    if (err) return res.send(err);

                    // 🔥 BORRAR COMISIONES
                    db.query(
                        'DELETE FROM commissions WHERE from_user_id = ? OR to_user_id = ?',
                        [userId, userId],
                        (err) => {

                            if (err) return res.send(err);

                            // 🔥 BORRAR ALERTAS
                            db.query(
                                'DELETE FROM alerts WHERE user_id = ?',
                                [userId],
                                (err) => {

                                    if (err) return res.send(err);

                                    // 🔥 BORRAR USUARIO
                                    db.query(
                                        'DELETE FROM users WHERE id = ?',
                                        [userId],
                                        (err) => {

                                            if (err) return res.send(err);

                                            res.send({
                                                success: true,
                                                message: 'Usuario eliminado correctamente'
                                            });

                                        }
                                    );

                                }
                            );

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

            let pago = 22;
            if (total >= 10) pago = 53;
            if (total >= 20) pago = 130;

            res.send({ total_personas: total, pago_mensual: pago });
        }
    );
});

app.post('/validate-sponsor', (req, res) => {

    const { codigo } = req.body;

    db.query(
        'SELECT * FROM users WHERE codigo = ? AND estado = "activo"',
        [codigo],
        (err, result) => {

            if (err) return res.send(err);

            if (result.length > 0) {

                res.send({
                    success: true,
                    sponsor: result[0]
                });

            } else {

                res.send({
                    success: false,
                    message: 'Link inválido o usuario inactivo'
                });

            }
        }
    );
});

// ==============================
// SERVIDOR
// ==============================
app.listen(3000, () => {
    console.log('Servidor corriendo en puerto 3000');
});