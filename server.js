const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();

app.use(express.json());
app.use(cors());

// ==============================
// CONEXIÓN MYSQL
// ==============================

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
// REGISTER
// ==============================

app.post('/register', (req, res) => {

    const { nombre, email, telefono, password, sponsor_id } = req.body;

    db.query(
        'SELECT COUNT(*) AS total FROM users WHERE sponsor_id = ?',
        [sponsor_id],
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            const total = result[0].total;

            db.query(
                'SELECT email FROM users WHERE id = ?',
                [sponsor_id],
                (err, sponsorResult) => {

                    if (err) {
                        return res.status(500).send({ success: false, message: 'Error en el servidor' });
                    }

                    const sponsorEmail = sponsorResult[0]?.email || '';

                    if (sponsorEmail !== 'quecuriosodia@gmail.com' && total >= 12) {
                        return res.send({
                            success: false,
                            message: 'Este usuario ya tiene 12 directos'
                        });
                    }

                    db.query(
                        `INSERT INTO users
                        (codigo, nombre, email, telefono, password, sponsor_id, estado)
                        VALUES (NULL, ?, ?, ?, ?, ?, "pendiente")`,
                        [nombre, email, telefono, password, sponsor_id],
                        (err) => {

                            if (err) {
                                return res.status(500).send({ success: false, message: 'Error en el servidor' });
                            }

                            res.send({
                                success: true,
                                message: 'Usuario registrado correctamente'
                            });
                        }
                    );
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

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            if (results.length > 0) {
                res.json({ success: true, user: results[0] });
            } else {
                res.json({ success: false, message: 'Credenciales incorrectas' });
            }
        }
    );
});

// ==============================
// USERS
// ==============================

app.get('/users', (req, res) => {

    db.query(
        'SELECT * FROM users',
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            res.send(result);
        }
    );
});

// ==============================
// ACTIVAR
// ==============================

app.post('/activate/:id', (req, res) => {

    const userId = req.params.id;

    db.query(
        'SELECT * FROM users WHERE id = ?',
        [userId],
        (err, directos) => {

    if (err) {
        return res.status(500).send({
            success: false,
            message: 'Error en el servidor'
        });
    }
        (err, resultEstado) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            if (resultEstado.length === 0) {
                return res.send({ success: false, message: 'Usuario no encontrado' });
            }

            if (resultEstado[0].estado === 'activo') {
                return res.send({ success: false, message: 'Este usuario ya está activo' });
            }

            const sponsor_id = resultEstado[0].sponsor_id;

            db.query(
                'SELECT MAX(codigo) AS maxCodigo FROM users',
                (err, resultCodigo) => {

                    if (err) {
                        return res.status(500).send({ success: false, message: 'Error en el servidor' });
                    }

                    let nuevoCodigo = resultCodigo[0].maxCodigo
                        ? resultCodigo[0].maxCodigo + 1
                        : 501;

                    db.query(
                        "UPDATE users SET estado = 'activo', codigo = ? WHERE id = ?",
                        [nuevoCodigo, userId],
                        (err) => {

                            if (err) {
                                return res.status(500).send({ success: false, message: 'Error en el servidor' });
                            }

                            db.query(
                                `SELECT COUNT(*) as total
                                 FROM users
                                 WHERE sponsor_id = ?
                                 OR sponsor_id IN (
                                     SELECT id FROM users WHERE sponsor_id = ?
                                 )`,
                                [userId, userId],
                                (err, redUsuarioResult) => {

                                    if (err) {
                                        return res.status(500).send({ success: false, message: 'Error en el servidor' });
                                    }

                                    const totalRedUsuario = redUsuarioResult[0].total;

                                    let montoComision = 22;
                                    if (totalRedUsuario >= 20) {
                                        montoComision = 127;
                                    } else if (totalRedUsuario >= 10) {
                                        montoComision = 50;
                                    }

                                    db.query(
                                        'SELECT COUNT(*) AS total FROM users WHERE sponsor_id = ? AND estado = "activo"',
                                        [sponsor_id],
                                        (err, countResult) => {

                                            if (err) {
                                                return res.status(500).send({ success: false, message: 'Error en el servidor' });
                                            }

                                            const numero = countResult[0].total;

                                            db.query(
                                                'SELECT sponsor_id FROM users WHERE id = ?',
                                                [sponsor_id],
                                                (err, sponsorData) => {

                                                    if (err) {
                                                        return res.status(500).send({ success: false, message: 'Error en el servidor' });
                                                    }

                                                    const sponsorDelSponsor = sponsorData[0]?.sponsor_id || null;

                                                    let beneficiario;
                                                    if ([1, 4, 7, 10].includes(numero)) {
                                                        beneficiario = sponsorDelSponsor;
                                                    } else {
                                                        beneficiario = sponsor_id;
                                                    }

                                                    if (beneficiario) {
                                                        db.query(
                                                            'INSERT INTO commissions (from_user_id, to_user_id, monto, nivel) VALUES (?, ?, ?, 1)',
                                                            [userId, beneficiario, montoComision]
                                                        );
                                                    }

                                                    db.query(
                                                        `SELECT COUNT(*) as total
                                                         FROM users
                                                         WHERE sponsor_id = ?
                                                         OR sponsor_id IN (
                                                             SELECT id FROM users WHERE sponsor_id = ?
                                                         )`,
                                                        [sponsor_id, sponsor_id],
                                                        (err, redSponsorResult) => {

                                                            if (err) {
                                                                return res.status(500).send({ success: false, message: 'Error en el servidor' });
                                                            }

                                                            const totalRedSponsor = redSponsorResult[0].total;

                                                            if (totalRedSponsor === 10) {
                                                                db.query(
                                                                    'INSERT INTO alerts (user_id, mensaje) VALUES (?, ?)',
                                                                    [sponsor_id, 'Usuario alcanzó 10 personas y debe subir a $53']
                                                                );
                                                            }

                                                            if (totalRedSponsor === 20) {
                                                                db.query(
                                                                    'INSERT INTO alerts (user_id, mensaje) VALUES (?, ?)',
                                                                    [sponsor_id, 'Usuario alcanzó 20 personas y debe subir a $130']
                                                                );
                                                            }

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
});
});

// ==============================
// DESACTIVAR
// ==============================

app.post('/deactivate/:id', (req, res) => {

    const userId = req.params.id;

    db.query(
        'SELECT sponsor_id, estado FROM users WHERE id = ?',
        [userId],
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            if (result.length === 0) {
                return res.send({ success: false, message: 'Usuario no encontrado' });
            }

            if (result[0].estado === 'inactivo') {
                return res.send({ success: false, message: 'Este usuario ya está inactivo' });
            }

            const sponsor = result[0].sponsor_id;

            db.query(
                'UPDATE users SET sponsor_id = ? WHERE sponsor_id = ?',
                [sponsor, userId],
                (err) => {

                    if (err) {
                        return res.status(500).send({ success: false, message: 'Error en el servidor' });
                    }

                    db.query(
                        "UPDATE users SET estado = 'inactivo' WHERE id = ?",
                        [userId],
                        (err) => {

                            if (err) {
                                return res.status(500).send({ success: false, message: 'Error en el servidor' });
                            }

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
// ELIMINAR USUARIO
// ==============================

app.post('/delete-user/:id', (req, res) => {

    const userId = req.params.id;
    const { adminPassword } = req.body;

    if (adminPassword !== process.env.ADMIN_PASSWORD) {
        return res.send({ success: false, message: 'Clave incorrecta' });
    }

    db.query(
        'SELECT sponsor_id FROM users WHERE id = ?',
        [userId],
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            if (result.length === 0) {
                return res.send({ success: false, message: 'Usuario no encontrado' });
            }

            const sponsor = result[0].sponsor_id;

            db.query(
                'UPDATE users SET sponsor_id = ? WHERE sponsor_id = ?',
                [sponsor, userId],
                (err) => {

                    if (err) {
                        return res.status(500).send({ success: false, message: 'Error en el servidor' });
                    }

                    db.query(
                        'DELETE FROM commissions WHERE from_user_id = ? OR to_user_id = ?',
                        [userId, userId],
                        (err) => {

                            if (err) {
                                return res.status(500).send({ success: false, message: 'Error en el servidor' });
                            }

                            db.query(
                                'DELETE FROM alerts WHERE user_id = ?',
                                [userId],
                                (err) => {

                                    if (err) {
                                        return res.status(500).send({ success: false, message: 'Error en el servidor' });
                                    }

                                    db.query(
                                        'DELETE FROM users WHERE id = ?',
                                        [userId],
                                        (err) => {

                                            if (err) {
                                                return res.status(500).send({ success: false, message: 'Error en el servidor' });
                                            }

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

    db.query(
        'SELECT * FROM commissions',
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            res.send(result);
        }
    );
});

app.get('/my-commissions/:id', (req, res) => {

    db.query(
        'SELECT * FROM commissions WHERE to_user_id = ?',
        [req.params.id],
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            res.send(result);
        }
    );
});

app.get('/my-total/:id', (req, res) => {

    db.query(
        'SELECT SUM(monto) as total FROM commissions WHERE to_user_id = ?',
        [req.params.id],
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            res.send(result[0]);
        }
    );
});

// ==============================
// RED
// FIX: El bloque original tenía dos versiones mezcladas del endpoint
// (una con JOIN y otra con lógica manual) y rutas anidadas adentro
// de callbacks. Se unificó en una sola versión limpia y correcta.
// ==============================

app.get('/my-network/:id', (req, res) => {

    const userId = req.params.id;

    // PASO 1: Obtener directos
    db.query(
        `SELECT id, codigo, nombre, estado
         FROM users
         WHERE sponsor_id = ?`,
        [userId],
        (err, directos) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            // PASO 2: Obtener indirectos
            db.query(
                `SELECT id, codigo, nombre, estado
                 FROM users
                 WHERE sponsor_id IN (
                     SELECT id FROM users WHERE sponsor_id = ?
                 )`,
                [userId],
                (err, indirectos) => {

                    if (err) {
                        return res.status(500).send({ success: false, message: 'Error en el servidor' });
                    }

                    // PASO 3: Marcar qué posiciones generan comisión
                    const nuevosDirectos = directos.map((u, index) => {
                        // Posiciones 1, 4, 7, 10 (base 1) van al sponsor del sponsor
                        // Las demás generan comisión directa
                        u.genera_comision = ![0, 3, 6, 9].includes(index);
                        u.nivel_generador = 0;
                        return u;
                    });

                    const nuevosIndirectos = indirectos.map((u) => {
                        u.genera_comision = true;
                        u.nivel_generador = 0;
                        return u;
                    });

                    const todos = [...nuevosDirectos, ...nuevosIndirectos];

                    // Si no hay nadie en la red, responder de inmediato
                    if (todos.length === 0) {
                        return res.send({
                            directos: nuevosDirectos,
                            indirectos: nuevosIndirectos
                        });
                    }

                    // PASO 4: Calcular nivel_generador para cada persona
                    let pendientes = todos.length;

                    todos.forEach((usuario) => {

                        db.query(
                            `SELECT COUNT(*) as total
                             FROM commissions
                             WHERE to_user_id = ?`,
                            [usuario.id],
                            (err, result) => {

                                if (!err) {
                                    const total = result[0].total;
                                    if (total >= 20) {
                                        usuario.nivel_generador = 20;
                                    } else if (total >= 10) {
                                        usuario.nivel_generador = 10;
                                    }
                                }

                                pendientes--;

                                if (pendientes === 0) {
                                    res.send({
                                        directos: nuevosDirectos,
                                        indirectos: nuevosIndirectos
                                    });
                                }
                            }
                        );
                    });
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
         FROM commissions
         WHERE to_user_id = ?`,
        [userId],
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            const total = result[0].total;

            let pago = 22;
            if (total >= 20) {
                pago = 130;
            } else if (total >= 10) {
                pago = 53;
            }

            res.send({
                total_personas: total,
                pago_mensual: pago
            });
        }
    );
});

// ==============================
// VALIDAR SPONSOR
// ==============================

app.post('/validate-sponsor', (req, res) => {

    const { codigo } = req.body;

    db.query(
        'SELECT * FROM users WHERE codigo = ? AND estado = "activo"',
        [codigo],
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            if (result.length > 0) {
                res.send({ success: true, sponsor: result[0] });
            } else {
                res.send({ success: false, message: 'Link inválido o usuario inactivo' });
            }
        }
    );
});

// ==============================
// CAMBIAR PASSWORD
// ==============================

app.post('/change-password', (req, res) => {

    const { userId, currentPassword, newPassword } = req.body;

    db.query(
        'SELECT * FROM users WHERE id = ?',
        [userId],
        (err, result) => {

            if (err) {
                return res.status(500).send({ success: false, message: 'Error en el servidor' });
            }

            if (result.length === 0) {
                return res.send({ success: false, message: 'Usuario no encontrado' });
            }

            if (result[0].password !== currentPassword) {
                return res.send({ success: false, message: 'Contraseña actual incorrecta' });
            }

            db.query(
                'UPDATE users SET password = ? WHERE id = ?',
                [newPassword, userId],
                (err) => {

                    if (err) {
                        return res.status(500).send({ success: false, message: 'Error en el servidor' });
                    }

                    res.send({
                        success: true,
                        message: 'Contraseña actualizada correctamente'
                    });
                }
            );
        }
    );
});

// ==============================
// SERVER
// ==============================

app.listen(3000, () => {
    console.log('Servidor corriendo en puerto 3000');
});