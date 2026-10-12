import React, { useState, useEffect } from 'react';
import { Plus, Edit, X } from 'lucide-react';
import { adminClient } from '../api/adminClient';
import { AdminUser, CatalogItem } from '../types/admin';

interface CatalogTabProps {
  admin: AdminUser | null;
}

export const CatalogTab: React.FC<CatalogTabProps> = ({ admin }) => {
  const [items, setItems] = useState<CatalogItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);

  // Form State
  const [itemId, setItemId] = useState('');
  const [name, setName] = useState('');
  const [category, setCategory] = useState('DICE');
  const [priceCoins, setPriceCoins] = useState(1000);
  const [priceGems, setPriceGems] = useState(50);
  const [rarity, setRarity] = useState('COMMON');
  const [isActive, setIsActive] = useState(true);

  const [message, setMessage] = useState<{ text: string; type: 'success' | 'error' } | null>(null);

  const loadCatalog = async () => {
    setIsLoading(true);
    try {
      const data = await adminClient.listCatalog();
      setItems(data);
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to load catalog', type: 'error' });
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadCatalog();
  }, []);

  const handleEdit = (item: CatalogItem) => {
    setItemId(item.id);
    setName(item.name);
    setCategory(item.category);
    setPriceCoins(item.price_coins);
    setPriceGems(item.price_gems);
    setRarity(item.rarity);
    setIsActive(item.is_active);
    setModalOpen(true);
  };

  const handleCreateNew = () => {
    setItemId('');
    setName('');
    setCategory('DICE');
    setPriceCoins(1000);
    setPriceGems(50);
    setRarity('RARE');
    setIsActive(true);
    setModalOpen(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await adminClient.upsertCatalogItem({
        id: itemId,
        name,
        category,
        price_coins: priceCoins,
        price_gems: priceGems,
        rarity,
        is_active: isActive,
      });
      setMessage({ text: `Catalog item ${name} saved successfully`, type: 'success' });
      setModalOpen(false);
      loadCatalog();
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to save item', type: 'error' });
    }
  };

  const isSuperAdmin = admin?.role === 'SUPER_ADMIN';

  return (
    <div className="panel">
      <div className="panel-header">
        <h2 className="panel-title">Economy Catalog &amp; Cosmetics</h2>

        {isSuperAdmin && (
          <button className="btn btn-primary btn-sm" onClick={handleCreateNew}>
            <Plus size={14} />
            <span>Add Catalog Item</span>
          </button>
        )}
      </div>

      {message && (
        <div
          style={{
            margin: '16px 24px 0',
            padding: '12px 16px',
            borderRadius: '8px',
            backgroundColor: message.type === 'success' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
            color: message.type === 'success' ? 'var(--accent-emerald)' : 'var(--accent-rose)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <span>{message.text}</span>
          <button
            onClick={() => setMessage(null)}
            style={{ background: 'transparent', border: 'none', color: 'inherit', cursor: 'pointer' }}
          >
            <X size={16} />
          </button>
        </div>
      )}

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>Item ID</th>
              <th>Name</th>
              <th>Category</th>
              <th>Price (Coins)</th>
              <th>Price (Gems)</th>
              <th>Rarity</th>
              <th>Status</th>
              {isSuperAdmin && <th>Actions</th>}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={8} style={{ textAlign: 'center', padding: '32px' }}>
                  Loading catalog items...
                </td>
              </tr>
            ) : items.length === 0 ? (
              <tr>
                <td colSpan={8} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                  No items in catalog.
                </td>
              </tr>
            ) : (
              items.map((it) => (
                <tr key={it.id}>
                  <td>
                    <code>{it.id}</code>
                  </td>
                  <td>
                    <strong>{it.name}</strong>
                  </td>
                  <td>
                    <span className="badge badge-purple">{it.category}</span>
                  </td>
                  <td style={{ color: 'var(--accent-amber)', fontWeight: 600 }}>
                    {it.price_coins.toLocaleString()} C
                  </td>
                  <td style={{ color: 'var(--accent-purple)', fontWeight: 600 }}>
                    {it.price_gems.toLocaleString()} G
                  </td>
                  <td>
                    <span className="badge badge-cyan">{it.rarity}</span>
                  </td>
                  <td>
                    <span className={`badge ${it.is_active ? 'badge-active' : 'badge-suspended'}`}>
                      {it.is_active ? 'Active' : 'Disabled'}
                    </span>
                  </td>
                  {isSuperAdmin && (
                    <td>
                      <button
                        className="btn btn-secondary btn-sm"
                        onClick={() => handleEdit(it)}
                      >
                        <Edit size={13} />
                        <span>Edit</span>
                      </button>
                    </td>
                  )}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Upsert Modal */}
      {modalOpen && (
        <div className="modal-overlay" onClick={() => setModalOpen(false)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <form onSubmit={handleSubmit}>
              <div className="modal-header">
                <h3>{itemId ? 'Edit Item' : 'New Catalog Item'}</h3>
                <button
                  type="button"
                  onClick={() => setModalOpen(false)}
                  style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}
                >
                  <X size={20} />
                </button>
              </div>

              <div className="modal-body">
                <div>
                  <label className="kpi-label">Item Unique ID</label>
                  <input
                    type="text"
                    required
                    disabled={!!items.find((i) => i.id === itemId)}
                    className="search-input"
                    style={{ width: '100%', marginTop: '4px' }}
                    placeholder="e.g. dice_neon_gold"
                    value={itemId}
                    onChange={(e) => setItemId(e.target.value)}
                  />
                </div>

                <div>
                  <label className="kpi-label">Display Name</label>
                  <input
                    type="text"
                    required
                    className="search-input"
                    style={{ width: '100%', marginTop: '4px' }}
                    placeholder="e.g. Neon Gold Cyber Dice"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div>
                    <label className="kpi-label">Category</label>
                    <select
                      className="select-input"
                      style={{ width: '100%', marginTop: '4px' }}
                      value={category}
                      onChange={(e) => setCategory(e.target.value)}
                    >
                      <option value="DICE">Dice Skin</option>
                      <option value="TOKEN">Token Skin</option>
                      <option value="THEME">Board Theme</option>
                      <option value="EMOTE">Emote Pack</option>
                      <option value="AVATAR_FRAME">Avatar Frame</option>
                    </select>
                  </div>

                  <div>
                    <label className="kpi-label">Rarity</label>
                    <select
                      className="select-input"
                      style={{ width: '100%', marginTop: '4px' }}
                      value={rarity}
                      onChange={(e) => setRarity(e.target.value)}
                    >
                      <option value="COMMON">Common</option>
                      <option value="RARE">Rare</option>
                      <option value="EPIC">Epic</option>
                      <option value="LEGENDARY">Legendary</option>
                    </select>
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div>
                    <label className="kpi-label">Coins Price</label>
                    <input
                      type="number"
                      className="search-input"
                      style={{ width: '100%', marginTop: '4px' }}
                      value={priceCoins}
                      min={0}
                      onChange={(e) => setPriceCoins(parseInt(e.target.value) || 0)}
                    />
                  </div>

                  <div>
                    <label className="kpi-label">Gems Price</label>
                    <input
                      type="number"
                      className="search-input"
                      style={{ width: '100%', marginTop: '4px' }}
                      value={priceGems}
                      min={0}
                      onChange={(e) => setPriceGems(parseInt(e.target.value) || 0)}
                    />
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '8px' }}>
                  <input
                    type="checkbox"
                    id="isActive"
                    checked={isActive}
                    onChange={(e) => setIsActive(e.target.checked)}
                  />
                  <label htmlFor="isActive" style={{ fontSize: '14px', cursor: 'pointer' }}>
                    Active in Store
                  </label>
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setModalOpen(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  Save Item
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
