import cron from 'node-cron';
import pool from '../database/pool.js';

export function startCapsuleUnlockJob() {
    cron.schedule('0 * * * *', async () => {
        console.log(' Checking for capsules to unlock...');

        try {
            const query = `
                SELECT * FROM time_capsules
                WHERE is_locked = true
                  AND unlock_date <= NOW()
            `;

            const result = await pool.query(query);
            const capsules = result.rows;

            if (capsules.length === 0) {
                console.log('No capsules ready to unlock');
                return;
            }

            console.log(`Found ${capsules.length} capsule(s) to unlock`);

            for (const capsule of capsules) {
                try {
                    await pool.query(
                        'UPDATE time_capsules SET is_locked = false WHERE id = $1',
                        [capsule.id]
                    );

                    console.log(`Unlocked capsule: ${capsule.title} (${capsule.id})`);

                    // TODO: Send notifications to group members

                } catch (error) {
                    console.error(` Failed to unlock capsule ${capsule.id}:`, error);
                }
            }

        } catch (error) {
            console.error('Error in capsule unlock job:', error);
        }
    });

    console.log(' Capsule unlock job started (runs every hour)');
}