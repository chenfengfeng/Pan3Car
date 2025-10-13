// /www/wwwroot/pan3/cli/resume-tasks.js

import fs from 'fs/promises';
import path from 'path';
import { execFile } from 'child_process';

const TASKS_FILE_PATH = path.join(process.cwd(), 'charge_tasks.json');

async function resumeRunningTasks() {
    console.log('[Resume Script] 开始检查需要恢复的任务...');
    try {
        const fileData = await fs.readFile(TASKS_FILE_PATH, 'utf8');
        const tasks = JSON.parse(fileData);
        let tasksUpdated = false;

        for (const vin in tasks) {
            const task = tasks[vin];
            // 增加健壮性检查，确保 task 和 task.taskDetails 都存在
            if (task && task.taskDetails && (task.status === 'PREPARING' || task.status === 'RUNNING')) {
                console.log(`[Resume Script] 发现需要恢复的任务, VIN: ${vin}`);
                
                const cliPayload = { ...task.taskDetails };
                const payloadBase64 = Buffer.from(JSON.stringify(cliPayload)).toString('base64');
                const scriptPath = path.join(process.cwd(), 'cli', 'tasks', 'charge-monitoring-workflow.js');
                
                const child = execFile('node', [scriptPath, payloadBase64], (error, stdout, stderr) => {
                    if (error) { console.error(`[Resumed CLI] - VIN: ${vin} - 脚本出错:`, error); }
                });

                tasks[vin].pid = child.pid;
                tasksUpdated = true;
                console.log(`[Resume Script] 任务已重新启动, VIN: ${vin}, 新PID: ${child.pid}`);
            }
        }

        if (tasksUpdated) {
            await fs.writeFile(TASKS_FILE_PATH, JSON.stringify(tasks, null, 2));
            console.log('[Resume Script] 任务文件已更新。');
        } else {
            console.log('[Resume Script] 没有发现需要恢复的任务。');
        }
    } catch (error) {
        if (error.code !== 'ENOENT') { // 忽略文件不存在的错误
            console.error('[Resume Script] 恢复任务时发生错误:', error);
        }
    }
}

resumeRunningTasks();