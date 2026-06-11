import express from 'express';
import path from 'path';
import fs from 'fs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import multer from 'multer';
import { createServer as createViteServer } from 'vite';

const PORT = 3000;
const DB_FILE = path.join(process.cwd(), 'db.json');
const UPLOADS_DIR = path.join(process.cwd(), 'uploads');
const JWT_SECRET = 'ras_applet_jwt_token_secret_091823908';

// Create directories if they don't exist
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

// Database Scheme
interface DatabaseSchema {
  users: any[];
  projects: any[];
  projectUsers: any[];
  sectionItems: any[];
  files: any[];
}

// Helper to load/save database state
function loadDB(): DatabaseSchema {
  if (fs.existsSync(DB_FILE)) {
    try {
      const data = fs.readFileSync(DB_FILE, 'utf-8');
      return JSON.parse(data);
    } catch (e) {
      console.error('Error parsing db.json, resetting database', e);
    }
  }
  
  // Seed initial Admin and Regular user
  const adminSalt = bcrypt.genSaltSync(10);
  const userSalt = bcrypt.genSaltSync(10);
  const initialData: DatabaseSchema = {
    users: [
      {
        guid: 'admin-user-uuid-0000',
        name: 'Администратор Системы',
        login: 'admin',
        username: 'admin',
        email: 'admin@ras.ru',
        hashed_password: bcrypt.hashSync('admin12345', adminSalt),
        is_admin: true,
        is_active: true,
        role: 'admin',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      },
      {
        guid: 'test-user-uuid-1111',
        name: 'Алексей Иванов',
        login: 'tester',
        username: 'tester',
        email: 'test@ras.ru',
        hashed_password: bcrypt.hashSync('test12345', userSalt),
        is_admin: false,
        is_active: true,
        role: 'user',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }
    ],
    projects: [],
    projectUsers: [],
    sectionItems: [],
    files: [],
  };
  fs.writeFileSync(DB_FILE, JSON.stringify(initialData, null, 2), 'utf-8');
  return initialData;
}

function saveDB(data: DatabaseSchema) {
  fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2), 'utf-8');
}

// Ensure database is initialized
let db = loadDB();

// Setup multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const projectGuid = req.params.project_guid || 'shared';
    const projectDir = path.join(UPLOADS_DIR, projectGuid);
    if (!fs.existsSync(projectDir)) {
      fs.mkdirSync(projectDir, { recursive: true });
    }
    cb(null, projectDir);
  },
  filename: (req, file, cb) => {
    const fileGuid = crypto.randomUUID();
    const ext = path.extname(file.originalname);
    cb(null, `${fileGuid}${ext}`);
  }
});
const upload = multer({ storage, limits: { fileSize: 20 * 1024 * 1024 } }); // 20MB limit

async function startServer() {
  const app = express();

  // Middleware
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // JWT helper middleware
  const authenticateToken = (req: any, res: any, next: any) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ detail: 'Необходима авторизация' });
    }

    jwt.verify(token, JWT_SECRET, (err: any, tokenPayload: any) => {
      if (err) {
        return res.status(401).json({ detail: 'Недействительный или просроченный токен' });
      }
      const user = db.users.find(u => u.guid === tokenPayload.user_guid);
      if (!user) {
        return res.status(401).json({ detail: 'Пользователь не найден' });
      }
      if (!user.is_active) {
        return res.status(403).json({ detail: 'Аккаунт заблокирован' });
      }
      req.user = user;
      next();
    });
  };

  const requireAdmin = (req: any, res: any, next: any) => {
    authenticateToken(req, res, () => {
      if (!req.user || !req.user.is_admin) {
        return res.status(403).json({ detail: 'Недостаточно прав администратора' });
      }
      next();
    });
  };

  // --- AUTH ENDPOINTS ---
  app.post('/api/users/register', (req, res) => {
    const { name, login, email, password } = req.body;
    const username = login || req.body.username;

    if (!email || !username || !password) {
      return res.status(400).json({ detail: 'Заполните обязательные поля: email, login, password' });
    }

    if (password.length < 8) {
      return res.status(400).json({ detail: 'Пароль должен содержать не менее 8 символов' });
    }

    const emailNorm = email.toLowerCase().trim();
    if (db.users.some(u => u.email.toLowerCase() === emailNorm || u.username.toLowerCase() === username.toLowerCase())) {
      return res.status(400).json({ detail: 'Email или username уже занят' });
    }

    const guid = crypto.randomUUID();
    const newUser = {
      guid,
      name: name || username,
      login: username,
      username,
      email: emailNorm,
      hashed_password: bcrypt.hashSync(password, 10),
      is_admin: false,
      is_active: true,
      role: 'user',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    db.users.push(newUser);
    saveDB(db);

    const accessToken = jwt.sign({ user_guid: guid, role: 'user' }, JWT_SECRET, { expiresIn: '1d' });
    const refreshToken = jwt.sign({ user_guid: guid }, JWT_SECRET, { expiresIn: '7d' });

    res.status(201).json({
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'bearer'
    });
  });

  app.post('/api/users/login', upload.none(), (req, res) => {
    // Can be sent via Form URL Encoded or Multipart Form Data or Standard JSON
    const email = req.body.email || req.body.username;
    const password = req.body.password;

    if (!email || !password) {
      return res.status(400).json({ detail: 'Введите email/логин и пароль' });
    }

    const emailNorm = email.toLowerCase().trim();
    const user = db.users.find(u => u.email.toLowerCase() === emailNorm || u.username.toLowerCase() === emailNorm);

    if (!user || !bcrypt.compareSync(password, user.hashed_password)) {
      return res.status(401).json({ detail: 'Неверный email или пароль' });
    }

    if (!user.is_active) {
      return res.status(403).json({ detail: 'Аккаунт заблокирован' });
    }

    const accessToken = jwt.sign({ user_guid: user.guid, role: user.role }, JWT_SECRET, { expiresIn: '1d' });
    const refreshToken = jwt.sign({ user_guid: user.guid }, JWT_SECRET, { expiresIn: '7d' });

    res.json({
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'bearer'
    });
  });

  app.post('/api/users/refresh', (req, res) => {
    const { refresh_token } = req.body;
    if (!refresh_token) {
      return res.status(401).json({ detail: 'Отсутствует refresh token' });
    }

    try {
      const payload: any = jwt.verify(refresh_token, JWT_SECRET);
      const user = db.users.find(u => u.guid === payload.user_guid);
      if (!user || !user.is_active) {
        return res.status(401).json({ detail: 'Пользователь не найден или заблокирован' });
      }

      const newAccess = jwt.sign({ user_guid: user.guid, role: user.role }, JWT_SECRET, { expiresIn: '1d' });
      const newRefresh = jwt.sign({ user_guid: user.guid }, JWT_SECRET, { expiresIn: '7d' });

      res.json({
        access_token: newAccess,
        refresh_token: newRefresh,
        token_type: 'bearer'
      });
    } catch (e) {
      return res.status(401).json({ detail: 'Недействительный refresh token' });
    }
  });

  app.post('/api/users/logout', (req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  app.get('/api/users', authenticateToken, (req: any, res) => {
    const { name, search } = req.query as any;
    const query = (name || search || '').toLowerCase();

    if (!query) {
      return res.json([]);
    }

    const matched = db.users
      .filter(u => 
        u.name.toLowerCase().includes(query) || 
        u.username.toLowerCase().includes(query) || 
        (u.email && u.email.toLowerCase().includes(query))
      )
      .map(u => ({
        guid: u.guid,
        name: u.name,
        username: u.username,
        email: u.email
      }));

    res.json(matched);
  });

  app.get('/api/users/me', authenticateToken, (req: any, res) => {
    res.json(req.user);
  });

  app.get('/api/users/all', requireAdmin, (req, res) => {
    const usersMapped = db.users.map(u => ({
      ...u,
      is_admin: !!(u.is_admin || u.role === 'admin')
    }));
    res.json(usersMapped);
  });

  app.put('/api/users/:user_guid', requireAdmin, (req, res) => {
    const { user_guid } = req.params;
    const { is_active, role, is_admin } = req.body;

    const user = db.users.find(u => u.guid === user_guid);
    if (!user) {
      return res.status(404).json({ detail: 'Пользователь не найден' });
    }

    if (is_active !== undefined) user.is_active = is_active;
    if (is_admin !== undefined) {
      user.is_admin = !!is_admin;
      user.role = user.is_admin ? 'admin' : 'user';
    } else if (role !== undefined) {
      user.role = role;
      user.is_admin = role === 'admin';
    }
    user.updated_at = new Date().toISOString();

    saveDB(db);
    res.json(user);
  });

  app.delete('/api/users/:user_guid', requireAdmin, (req, res) => {
    const { user_guid } = req.params;
    if (user_guid === (req as any).user.guid) {
      return res.status(400).json({ detail: 'Нельзя удалить самого себя' });
    }

    const idx = db.users.findIndex(u => u.guid === user_guid);
    if (idx === -1) {
      return res.status(404).json({ detail: 'Пользователь не найден' });
    }

    db.users.splice(idx, 1);
    saveDB(db);
    res.status(204).end();
  });

  // --- PROJECTS ENDPOINTS ---
  app.get('/api/projects', authenticateToken, (req: any, res) => {
    const { search, sort_by = 'created_at', sort_order = 'desc' } = req.query as any;

    let filtered = db.projects;
    // Non-admin can only see own projects or projects where they are added
    if (!req.user.is_admin) {
      const userProjectGuids = db.projectUsers
        .filter(pu => pu.user_guid === req.user.guid)
        .map(pu => pu.project_guid);

      filtered = db.projects.filter(p => p.owner_guid === req.user.guid || userProjectGuids.includes(p.guid));
    }

    if (search) {
      const query = search.toLowerCase();
      filtered = filtered.filter(p => 
        p.name.toLowerCase().includes(query) || 
        (p.description && p.description.toLowerCase().includes(query))
      );
    }

    filtered.sort((a, b) => {
      const fieldA = a[sort_by] || '';
      const fieldB = b[sort_by] || '';
      if (sort_order === 'asc') {
        return fieldA > fieldB ? 1 : -1;
      } else {
        return fieldA < fieldB ? 1 : -1;
      }
    });

    res.json(filtered);
  });

  app.post('/api/projects', authenticateToken, (req: any, res) => {
    const { name, description, status = 'draft', customer = '' } = req.body;
    if (!name) {
      return res.status(400).json({ detail: 'Укажите название проекта' });
    }

    const guid = crypto.randomUUID();
    const newProject = {
      guid,
      name,
      description,
      status,
      customer,
      owner_guid: req.user.guid,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      created_by: req.user.guid,
      updated_by: req.user.guid,
      created_by_name: req.user.name,
      updated_by_name: req.user.name,
      abstract: '',
      annotation_stats: 0,
      requirement_stats: 0,
      common_stats: 0
    };

    db.projects.push(newProject);
    // Add owner as a member
    db.projectUsers.push({
      guid: crypto.randomUUID(),
      project_guid: guid,
      user_guid: req.user.guid,
      role: 'owner',
      created_at: new Date().toISOString(),
    });

    saveDB(db);
    res.status(201).json(newProject);
  });

  app.get('/api/projects/:project_guid', authenticateToken, (req: any, res) => {
    const { project_guid } = req.params;
    const project = db.projects.find(p => p.guid === project_guid);
    if (!project) {
      return res.status(404).json({ detail: 'Проект не найден' });
    }
    res.json(project);
  });

  app.put('/api/projects/:project_guid', authenticateToken, (req, res) => {
    const { project_guid } = req.params;
    const project = db.projects.find(p => p.guid === project_guid);
    if (!project) {
      return res.status(404).json({ detail: 'Проект не найден' });
    }

    const updatableFields = ['name', 'description', 'status', 'customer', 'abstract'];
    updatableFields.forEach(field => {
      if (req.body[field] !== undefined) {
        project[field] = req.body[field];
      }
    });

    project.updated_at = new Date().toISOString();
    saveDB(db);
    res.json(project);
  });

  app.delete('/api/projects/:project_guid', authenticateToken, (req: any, res) => {
    const { project_guid } = req.params;
    const projectIdx = db.projects.findIndex(p => p.guid === project_guid);
    if (projectIdx === -1) {
      return res.status(404).json({ detail: 'Проект не найден' });
    }

    const project = db.projects[projectIdx];
    if (project.owner_guid !== req.user.guid && !req.user.is_admin) {
      return res.status(403).json({ detail: 'Только владелец может удалить проект' });
    }

    db.projects.splice(projectIdx, 1);
    db.projectUsers = db.projectUsers.filter(pu => pu.project_guid !== project_guid);
    db.sectionItems = db.sectionItems.filter(si => si.project_guid !== project_guid);
    saveDB(db);
    res.status(204).end();
  });

  // --- MEMBERS ---
  app.get('/api/projects/:project_guid/users', authenticateToken, (req, res) => {
    const { project_guid } = req.params;
    const members = db.projectUsers.filter(pu => pu.project_guid === project_guid);
    res.json(members);
  });

  app.post('/api/projects/:project_guid/users', authenticateToken, (req: any, res) => {
    const { project_guid } = req.params;
    const { user_guid, role = 'viewer' } = req.body;

    const project = db.projects.find(p => p.guid === project_guid);
    if (!project) {
      return res.status(404).json({ detail: 'Проект не найден' });
    }

    if (project.owner_guid !== req.user.guid && !req.user.is_admin) {
      return res.status(403).json({ detail: 'Только владелец добавляет участников' });
    }

    const exists = db.projectUsers.some(pu => pu.project_guid === project_guid && pu.user_guid === user_guid);
    if (exists) {
      return res.status(400).json({ detail: 'Пользователь уже является участником проекта' });
    }

    const newMember = {
      guid: crypto.randomUUID(),
      project_guid,
      user_guid,
      role,
      created_at: new Date().toISOString(),
    };

    db.projectUsers.push(newMember);
    saveDB(db);
    res.status(201).json(newMember);
  });

  app.put('/api/projects/:project_guid/users/:user_guid', authenticateToken, (req: any, res) => {
    const { project_guid, user_guid } = req.params;
    const { role } = req.body;

    const project = db.projects.find(p => p.guid === project_guid);
    if (!project) {
      return res.status(404).json({ detail: 'Проект не найден' });
    }

    if (project.owner_guid !== req.user.guid && !req.user.is_admin) {
      return res.status(403).json({ detail: 'Недостаточно прав' });
    }

    const member = db.projectUsers.find(pu => pu.project_guid === project_guid && pu.user_guid === user_guid);
    if (!member) {
      return res.status(404).json({ detail: 'Участник не найден' });
    }

    member.role = role;
    saveDB(db);
    res.json(member);
  });

  app.delete('/api/projects/:project_guid/users/:user_guid', authenticateToken, (req: any, res) => {
    const { project_guid, user_guid } = req.params;

    const project = db.projects.find(p => p.guid === project_guid);
    if (!project) {
      return res.status(404).json({ detail: 'Проект не найден' });
    }

    if (project.owner_guid !== req.user.guid && !req.user.is_admin) {
      return res.status(403).json({ detail: 'Недостаточно прав' });
    }

    const idx = db.projectUsers.findIndex(pu => pu.project_guid === project_guid && pu.user_guid === user_guid);
    if (idx === -1) {
      return res.status(404).json({ detail: 'Участник не найден' });
    }

    db.projectUsers.splice(idx, 1);
    saveDB(db);
    res.status(204).end();
  });

  // --- STATS & PDF REPORT ---
  const SECTION_MAPPING = [
    { name: 'annotation', urlPrefix: 'annotation', weight: 5 },
    { name: 'business_goals', urlPrefix: 'business-goals', weight: 8 },
    { name: 'analogs', urlPrefix: 'analogs', weight: 3 },
    { name: 'requirements', urlPrefix: 'requirements', weight: 10 },
    { name: 'user_classes', urlPrefix: 'user-classes', weight: 5 },
    { name: 'user_stories', urlPrefix: 'user-stories', weight: 8 },
    { name: 'glossary_terms', urlPrefix: 'glossary-terms', weight: 5 },
    { name: 'use_cases', urlPrefix: 'use-cases', weight: 8 },
    { name: 'architecture', urlPrefix: 'architecture', weight: 10 }, // Increased slightly for diagram capabilities
    { name: 'data_flows', urlPrefix: 'data-flows', weight: 6 },
    { name: 'data_dictionary', urlPrefix: 'data-dictionary', weight: 6 },
    { name: 'non_functional_requirements', urlPrefix: 'non-functional-requirements', weight: 8 },
    { name: 'constraints', urlPrefix: 'constraints', weight: 5 },
    { name: 'system_requirements', urlPrefix: 'system-requirements', weight: 8 },
    { name: 'draft_tz', urlPrefix: 'draft-tz', weight: 5 },
    { name: 'final_tz', urlPrefix: 'final-tz', weight: 6 },
    { name: 'change_records', urlPrefix: 'changes', weight: 2 },
  ];

  app.get('/api/projects/:project_guid/stats', authenticateToken, (req, res) => {
    const { project_guid } = req.params;

    let earnedWeight = 0;
    const sectionsDetail: Record<string, number> = {};

    for (const sec of SECTION_MAPPING) {
      const count = db.sectionItems.filter(
        item => item.project_guid === project_guid && item.url_prefix === sec.urlPrefix
      ).length;
      sectionsDetail[sec.name] = count;
      if (count > 0) {
        earnedWeight += sec.weight;
      }
    }

    const totalWeight = SECTION_MAPPING.reduce((sum, s) => sum + s.weight, 0);
    const score = Math.round((earnedWeight / totalWeight) * 100 * 10) / 10;
    const filled = Object.values(sectionsDetail).filter(c => c > 0).length;
    const total = SECTION_MAPPING.length;

    res.json({
      project_guid,
      readiness_score: score,
      filled_sections: filled,
      total_sections: total,
      sections_detail: sectionsDetail,
    });
  });

  app.get('/api/projects/:project_guid/export/pdf', authenticateToken, (req, res) => {
    const { project_guid } = req.params;
    const project = db.projects.find(p => p.guid === project_guid);

    if (!project) {
      return res.status(404).json({ detail: 'Проект не найден' });
    }

    // Generate plain-text representation of technical specs which downloads as standard text but formatted beautifully
    let doc = `ТЕХНИЧЕСКОЕ ЗАДАНИЕ (REQUIREMENTS ANALYSIS SYSTEM)\n`;
    doc += `========================================================\n\n`;
    doc += `Проект: ${project.name}\n`;
    doc += `Описание: ${project.description || '—'}\n`;
    doc += `Статус: ${project.status}\n`;
    doc += `Заказчик: ${project.customer || '—'}\n`;
    doc += `Создан: ${new Date(project.created_at).toLocaleDateString('ru-RU')}\n`;
    doc += `--------------------------------------------------------\n\n`;

    SECTION_MAPPING.forEach(sec => {
      const items = db.sectionItems.filter(
        item => item.project_guid === project_guid && item.url_prefix === sec.urlPrefix
      );

      if (items.length > 0) {
        doc += `## Раздел: ${sec.name.replace(/_/g, ' ').toUpperCase()}\n`;
        doc += `--------------------------------------------------------\n`;
        items.forEach((item, index) => {
          doc += `${index + 1}. Название: ${item.title || 'Без названия'}\n`;
          if (item.content) {
            doc += `   Описание/Содержимое: ${item.content}\n`;
          }
          // Print other properties (extra fields stored dynamically)
          Object.keys(item).forEach(key => {
            if (!['guid', 'project_guid', 'url_prefix', 'title', 'content', 'order', 'created_by', 'created_at', 'updated_at'].includes(key)) {
              doc += `   ${key.charAt(0).toUpperCase() + key.slice(1)}: ${item[key]}\n`;
            }
          });
          doc += `\n`;
        });
        doc += `\n`;
      }
    });

    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="tz_${project_guid}.txt"`);
    res.send(doc);
  });

  // --- GENERAL SECTION CRUD ROUTER FACTORY ---
  const handleSectionList = (urlPrefix: string) => {
    return (req: any, res: any) => {
      const { project_guid } = req.params;
      const { search, sort_by = 'order', sort_order = 'asc' } = req.query;

      let items = db.sectionItems.filter(
        i => i.project_guid === project_guid && i.url_prefix === urlPrefix
      );

      if (search) {
        const q = search.toLowerCase();
        items = items.filter(
          i => (i.title && i.title.toLowerCase().includes(q)) || (i.content && i.content.toLowerCase().includes(q))
        );
      }

      items.sort((a, b) => {
        const valA = a[sort_by] !== undefined ? a[sort_by] : '';
        const valB = b[sort_by] !== undefined ? b[sort_by] : '';
        if (sort_order === 'desc') {
          return valA < valB ? 1 : -1;
        } else {
          return valA > valB ? 1 : -1;
        }
      });

      // Ensure each item has both id and guid correctly assigned
      const itemsWithIds = items.map(i => ({
        ...i,
        id: i.id || i.guid,
        guid: i.guid || i.id
      }));

      res.json(itemsWithIds);
    };
  };

  const handleSectionCreate = (urlPrefix: string) => {
    return (req: any, res: any) => {
      const { project_guid } = req.params;
      const { title, content, order = 0, extra = {} } = req.body;

      const guid = crypto.randomUUID();
      const newItem = {
        guid,
        id: guid,
        project_guid,
        url_prefix: urlPrefix,
        title,
        content,
        order: Number(order),
        created_by: req.user.guid,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        ...extra, // Merge specific schema extra properties
        ...req.body // Merge remaining specific fields
      };

      // Ensure some unique fields are preserved from payload
      delete newItem.extra;
      
      db.sectionItems.push(newItem);
      saveDB(db);
      res.status(201).json(newItem);
    };
  };

  const handleSectionGet = (urlPrefix: string) => {
    return (req: any, res: any) => {
      const { project_guid, item_guid } = req.params;
      const item = db.sectionItems.find(
        i => (i.guid === item_guid || i.id === item_guid) && i.project_guid === project_guid && i.url_prefix === urlPrefix
      );

      if (!item) {
        return res.status(404).json({ detail: 'Запись не найдена' });
      }
      res.json({
        ...item,
        id: item.id || item.guid,
        guid: item.guid || item.id
      });
    };
  };

  const handleSectionUpdate = (urlPrefix: string) => {
    return (req: any, res: any) => {
      const { project_guid, item_guid } = req.params;
      const item = db.sectionItems.find(
        i => (i.guid === item_guid || i.id === item_guid) && i.project_guid === project_guid && i.url_prefix === urlPrefix
      );

      if (!item) {
        return res.status(404).json({ detail: 'Запись не найдена' });
      }

      const body = { ...req.body, ...req.body.extra };
      delete body.extra;

      Object.keys(body).forEach(k => {
        if (body[k] !== undefined) {
          item[k] = body[k];
        }
      });

      item.updated_at = new Date().toISOString();
      saveDB(db);
      res.json({
        ...item,
        id: item.id || item.guid,
        guid: item.guid || item.id
      });
    };
  };

  const handleSectionDelete = (urlPrefix: string) => {
    return (req: any, res: any) => {
      const { project_guid, item_guid } = req.params;
      const idx = db.sectionItems.findIndex(
        i => (i.guid === item_guid || i.id === item_guid) && i.project_guid === project_guid && i.url_prefix === urlPrefix
      );

      if (idx === -1) {
        return res.status(404).json({ detail: 'Запись не найдена' });
      }

      db.sectionItems.splice(idx, 1);
      saveDB(db);
      res.status(204).end();
    };
  };

  // Register all 17 specification sections dynamically in Express
  const ALL_PREFIXES = [
    'requirements', 'annotation', 'business-goals', 'analogs', 'user-classes',
    'user-stories', 'glossary-terms', 'use-cases', 'architecture', 'data-flows',
    'data-dictionary', 'non-functional-requirements', 'constraints', 'system-requirements',
    'draft-tz', 'final-tz', 'changes'
  ];

  ALL_PREFIXES.forEach(prefix => {
    const baseRoute = `/api/projects/:project_guid/${prefix}`;
    app.get(baseRoute, authenticateToken, handleSectionList(prefix));
    app.post(baseRoute, authenticateToken, handleSectionCreate(prefix));
    app.get(`${baseRoute}/:item_guid`, authenticateToken, handleSectionGet(prefix));
    app.put(`${baseRoute}/:item_guid`, authenticateToken, handleSectionUpdate(prefix));
    app.delete(`${baseRoute}/:item_guid`, authenticateToken, handleSectionDelete(prefix));
  });

  // --- SPECIAL ALTERNATIVE ENDPOINTS FOR REQUIREMENTS ---
  // The frontend calls these endpoints directly for requirement details
  app.get('/api/requirements/:item_guid', authenticateToken, (req: any, res) => {
    const { item_guid } = req.params;
    const item = db.sectionItems.find(i => (i.guid === item_guid || i.id === item_guid) && i.url_prefix === 'requirements');
    if (!item) {
      return res.status(404).json({ detail: 'Требование не найдено' });
    }
    res.json({
      ...item,
      id: item.id || item.guid,
      guid: item.guid || item.id
    });
  });

  app.put('/api/requirements/:item_guid', authenticateToken, (req: any, res) => {
    const { item_guid } = req.params;
    const item = db.sectionItems.find(i => (i.guid === item_guid || i.id === item_guid) && i.url_prefix === 'requirements');
    if (!item) {
      return res.status(404).json({ detail: 'Требование не найдено' });
    }

    Object.keys(req.body).forEach(k => {
      if (req.body[k] !== undefined) {
        item[k] = req.body[k];
      }
    });

    item.updated_at = new Date().toISOString();
    saveDB(db);
    res.json({
      ...item,
      id: item.id || item.guid,
      guid: item.guid || item.id
    });
  });

  app.delete('/api/requirements/:item_guid', authenticateToken, (req: any, res) => {
    const { item_guid } = req.params;
    const idx = db.sectionItems.findIndex(i => (i.guid === item_guid || i.id === item_guid) && i.url_prefix === 'requirements');
    if (idx === -1) {
      return res.status(404).json({ detail: 'Требование не найдено' });
    }

    db.sectionItems.splice(idx, 1);
    saveDB(db);
    res.status(204).end();
  });

  // Handle trailing slashes version calls standardly (Vue can make request/ API calls with trailing slash)
  app.put('/api/requirements/:item_guid/', authenticateToken, (req: any, res) => {
    const { item_guid } = req.params;
    const item = db.sectionItems.find(i => (i.guid === item_guid || i.id === item_guid) && i.url_prefix === 'requirements');
    if (!item) {
      return res.status(404).json({ detail: 'Требование не найдено' });
    }

    Object.keys(req.body).forEach(k => {
      if (req.body[k] !== undefined) {
        item[k] = req.body[k];
      }
    });

    item.updated_at = new Date().toISOString();
    saveDB(db);
    res.json({
      ...item,
      id: item.id || item.guid,
      guid: item.guid || item.id
    });
  });

  app.delete('/api/requirements/:item_guid/', authenticateToken, (req: any, res) => {
    const { item_guid } = req.params;
    const idx = db.sectionItems.findIndex(i => (i.guid === item_guid || i.id === item_guid) && i.url_prefix === 'requirements');
    if (idx === -1) {
      return res.status(404).json({ detail: 'Требование не найдено' });
    }

    db.sectionItems.splice(idx, 1);
    saveDB(db);
    res.status(204).end();
  });

  // --- INTEGRATED FILES MANAGEMENT ---
  app.post('/api/projects/:project_guid/files', authenticateToken, upload.single('file'), (req: any, res) => {
    const { project_guid } = req.params;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ detail: 'Загрузите файл' });
    }

    const fileGuid = path.basename(file.filename, path.extname(file.filename));
    const newFile = {
      guid: fileGuid,
      project_guid,
      filename: file.originalname,
      filepath: file.path,
      file_size: file.size,
      mime_type: file.mimetype,
      created_at: new Date().toISOString(),
    };

    db.files.push(newFile);
    saveDB(db);
    res.status(201).json(newFile);
  });

  app.get('/api/projects/:project_guid/files', authenticateToken, (req, res) => {
    const { project_guid } = req.params;
    const projectFiles = db.files.filter(f => f.project_guid === project_guid);
    res.json(projectFiles);
  });

  app.delete('/api/projects/:project_guid/files/:file_guid', authenticateToken, (req, res) => {
    const { project_guid, file_guid } = req.params;
    const idx = db.files.findIndex(f => f.guid === file_guid && f.project_guid === project_guid);

    if (idx === -1) {
      return res.status(404).json({ detail: 'Файл не найден' });
    }

    const fileObj = db.files[idx];
    if (fs.existsSync(fileObj.filepath)) {
      try {
        fs.unlinkSync(fileObj.filepath);
      } catch (e) {
        console.error('Error deleting file from disk', e);
      }
    }

    db.files.splice(idx, 1);
    saveDB(db);
    res.status(204).end();
  });

  // --- VITE DEV / PRODUCTION ENVIRONMENT SETUP ---
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[RAS Server] Full-stack application running at http://localhost:${PORT}`);
  });
}

startServer();
