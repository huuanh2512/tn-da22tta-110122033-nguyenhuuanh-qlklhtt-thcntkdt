#!/usr/bin/env node

/**
 * Notification System CLI Tracker
 * Test notification endpoints từ command line
 * 
 * Usage:
 *   node notification-tracker.js --token <jwt_token> --action <action>
 */

const http = require('http');

const args = process.argv.slice(2);
const TOKEN = args[args.indexOf('--token') + 1];
const ACTION = args[args.indexOf('--action') + 1] || 'list';

const BASE_URL = 'http://localhost:3000/api/v1';

if (!TOKEN) {
    console.error('❌ Error: JWT token required');
    console.log('Usage: node notification-tracker.js --token <jwt_token> [options]');
    console.log('\nOptions:');
    console.log('  --action list              List all notifications');
    console.log('  --action send              Send a test notification');
    console.log('  --action mark <id>         Mark notification as read');
    console.log('  --action mark-all          Mark all notifications as read');
    console.log('  --action register-fcm      Register FCM token');
    process.exit(1);
}

// HTTP request helper
function makeRequest(method, path, body = null) {
    return new Promise((resolve, reject) => {
        const url = new URL(BASE_URL + path);
        const options = {
            hostname: url.hostname,
            port: url.port,
            path: url.pathname + url.search,
            method: method,
            headers: {
                'Authorization': `Bearer ${TOKEN}`,
                'Content-Type': 'application/json'
            }
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(data);
                    resolve({status: res.statusCode, data: json});
                } catch (e) {
                    resolve({status: res.statusCode, data: data});
                }
            });
        });

        req.on('error', reject);
        if (body) req.write(JSON.stringify(body));
        req.end();
    });
}

// Actions
const actions = {
    list: async () => {
        console.log('📥 Fetching notifications...\n');
        const result = await makeRequest('GET', '/notification');
        if (result.status === 200) {
            const {unreadCount, items, total} = result.data;
            console.log(`✅ Loaded ${items.length} notifications (${unreadCount} unread)\n`);
            items.forEach((item, idx) => {
                console.log(`${idx + 1}. [${item.type}] ${item.title}`);
                console.log(`   Content: ${item.content.substring(0, 60)}...`);
                console.log(`   Status: ${item.isRead ? '✅ Read' : '❌ Unread'}`);
                console.log(`   Date: ${new Date(item.createdAt).toLocaleString('vi-VN')}\n`);
            });
        } else {
            console.error('❌ Error:', result.data.message);
        }
    },

    send: async () => {
        const readline = require('readline');
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        const ask = (question) => new Promise(resolve => rl.question(question, resolve));

        console.log('📤 Create Test Notification\n');
        const userId = await ask('User ID: ');
        const title = await ask('Title: ');
        const content = await ask('Content: ');
        const typeAnswer = await ask('Type (SYSTEM/BOOKING/PAYMENT/PROMOTION) [SYSTEM]: ');
        const type = typeAnswer || 'SYSTEM';

        rl.close();

        const body = {userId, title, content, type};
        console.log('\n📨 Sending...');
        const result = await makeRequest('POST', '/notification', body);

        if (result.status === 200) {
            console.log('✅ Notification sent successfully!\n');
            console.log(JSON.stringify(result.data.notification, null, 2));
        } else {
            console.error('❌ Error:', result.data.message);
        }
    },

    'mark-all': async () => {
        console.log('✅ Marking all notifications as read...\n');
        const result = await makeRequest('PUT', '/notification/mark-all-read');
        if (result.status === 200) {
            console.log('✅ All notifications marked as read');
        } else {
            console.error('❌ Error:', result.data.message);
        }
    },

    'register-fcm': async () => {
        const readline = require('readline');
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        const ask = (question) => new Promise(resolve => rl.question(question, resolve));

        console.log('📱 Register FCM Token\n');
        const token = await ask('FCM Token: ');
        rl.close();

        console.log('\n📨 Registering...');
        const result = await makeRequest('POST', '/user/register-fcm', {token});

        if (result.status === 200) {
            console.log('✅ FCM token registered successfully!\n');
            console.log(`Total FCM tokens: ${result.data.fcmTokenCount}`);
        } else {
            console.error('❌ Error:', result.data.message);
        }
    }
};

// Check if marked with ID
if (process.argv.includes('--id')) {
    const id = process.argv[process.argv.indexOf('--id') + 1];
    actions.mark = async () => {
        console.log(`⚠️ Marking notification ${id} as read...\n`);
        const result = await makeRequest('PUT', `/notification/${id}/read`);
        if (result.status === 200) {
            console.log('✅ Notification marked as read');
        } else {
            console.error('❌ Error:', result.data.message);
        }
    };
}

// Run action
const action = actions[ACTION];
if (action) {
    action().catch(err => {
        console.error('❌ Error:', err.message);
        process.exit(1);
    });
} else {
    console.error(`❌ Unknown action: ${ACTION}`);
    console.log('Available actions: list, send, mark-all, register-fcm');
    process.exit(1);
}
