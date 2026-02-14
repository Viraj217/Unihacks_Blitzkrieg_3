import express from 'express';
import {
    createVault,
    getVaultById,
    getGroupVaults,
    addMessage,
    updateMessage,
    deleteMessage,
    deleteVault
} from '../controllers/vaultController.js';
import { verifyUser } from '../middleware/verify.js';

const vaultrouter = express.Router();

// All routes require authentication
vaultrouter.use(verifyUser);

// Vault CRUD
vaultrouter.post('/', createVault);
vaultrouter.get('/:id', getVaultById);
vaultrouter.delete('/:id', deleteVault);

// Group vaults
vaultrouter.get('/group/:groupId', getGroupVaults);

// Vault messages
vaultrouter.post('/:id/messages', addMessage);
vaultrouter.put('/:id/messages/:messageId', updateMessage);
vaultrouter.delete('/:id/messages/:messageId', deleteMessage);

export default vaultrouter;
