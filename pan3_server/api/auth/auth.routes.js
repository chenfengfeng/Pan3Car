// /www/wwwroot/pan3/api/auth/auth.routes.js

import express from 'express';
import { login, logout } from './auth.controller.js';

const router = express.Router();

// 定义 /login 路径，使用POST方法，并指向 login 控制器函数
router.post('/login', login);

// 定义 /logout 路径，使用POST方法，并指向 logout 控制器函数
router.post('/logout', logout);

export default router;