package services

import (
	"database/sql"
	"encoding/json"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

// SettingsService provides methods to manage system settings
// It works with the settings table
// Settings are stored as key-value pairs per company

type SettingsService struct {
    db *sql.DB
}

// NewSettingsService creates a new SettingsService
func NewSettingsService() *SettingsService {
    s := &SettingsService{db: database.GetDB()}
    // Best-effort ensure permissions exist so the frontend can access
    // settings endpoints out of the box.
    _ = s.ensureSettingsPermissions()
    return s
}

// GetSettings retrieves all settings for a company
func (s *SettingsService) GetSettings(companyID int) (map[string]models.JSONB, error) {
	query := `SELECT key, value FROM settings WHERE company_id = $1`
	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get settings: %w", err)
	}
	defer rows.Close()

	settings := make(map[string]models.JSONB)
	for rows.Next() {
		var key string
		var value models.JSONB
		if err := rows.Scan(&key, &value); err != nil {
			return nil, fmt.Errorf("failed to scan setting: %w", err)
		}
		settings[key] = value
	}

	return settings, nil
}

// UpdateSettings updates or inserts multiple settings for a company
func (s *SettingsService) UpdateSettings(companyID int, settings map[string]models.JSONB) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`INSERT INTO settings (company_id, key, value) VALUES ($1, $2, $3)
            ON CONFLICT (company_id, key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP`)
	if err != nil {
		return fmt.Errorf("failed to prepare statement: %w", err)
	}
	defer stmt.Close()

	for k, v := range settings {
		if _, err := stmt.Exec(companyID, k, v); err != nil {
			return fmt.Errorf("failed to upsert setting %s: %w", k, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit settings: %w", err)
	}
	return nil
}

func (s *SettingsService) getJSONSetting(companyID int, key string, dest interface{}) error {
	var value models.JSONB
	err := s.db.QueryRow(`SELECT value FROM settings WHERE company_id=$1 AND key=$2`, companyID, key).Scan(&value)
	if err == sql.ErrNoRows {
		return nil
	}
	if err != nil {
		return fmt.Errorf("failed to get %s settings: %w", key, err)
	}
	b, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("failed to marshal %s settings: %w", key, err)
	}
	if err := json.Unmarshal(b, dest); err != nil {
		return fmt.Errorf("failed to unmarshal %s settings: %w", key, err)
	}
	return nil
}

func (s *SettingsService) updateJSONSetting(companyID int, key string, cfg interface{}) error {
	b, err := json.Marshal(cfg)
	if err != nil {
		return fmt.Errorf("failed to marshal %s settings: %w", key, err)
	}
	var value models.JSONB
	if err := json.Unmarshal(b, &value); err != nil {
		return fmt.Errorf("failed to unmarshal %s settings: %w", key, err)
	}
	return s.UpdateSettings(companyID, map[string]models.JSONB{key: value})
}

// Session limit settings
func (s *SettingsService) GetMaxSessions(companyID int) (int, error) {
	var value models.JSONB
	err := s.db.QueryRow(`SELECT value FROM settings WHERE company_id=$1 AND key='max_sessions'`, companyID).Scan(&value)
	if err == sql.ErrNoRows {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("failed to get max sessions: %w", err)
	}
	if v, ok := value["value"]; ok {
		switch num := v.(type) {
		case float64:
			return int(num), nil
		case int:
			return num, nil
		}
	}
	return 0, nil
}

func (s *SettingsService) SetMaxSessions(companyID, max int) error {
	value := models.JSONB{"value": max}
	return s.UpdateSettings(companyID, map[string]models.JSONB{"max_sessions": value})
}

func (s *SettingsService) DeleteMaxSessions(companyID int) error {
	_, err := s.db.Exec(`DELETE FROM settings WHERE company_id=$1 AND key='max_sessions'`, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete max sessions: %w", err)
	}
	return nil
}

// Company settings
func (s *SettingsService) GetCompanySettings(companyID int) (*models.CompanySettings, error) {
	var cfg models.CompanySettings
	if err := s.getJSONSetting(companyID, "company", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (s *SettingsService) UpdateCompanySettings(companyID int, cfg models.CompanySettings) error {
	return s.updateJSONSetting(companyID, "company", cfg)
}

// Invoice settings
func (s *SettingsService) GetInvoiceSettings(companyID int) (*models.InvoiceSettings, error) {
	var cfg models.InvoiceSettings
	if err := s.getJSONSetting(companyID, "invoice", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (s *SettingsService) UpdateInvoiceSettings(companyID int, cfg models.InvoiceSettings) error {
	return s.updateJSONSetting(companyID, "invoice", cfg)
}

// Tax settings
func (s *SettingsService) GetTaxSettings(companyID int) (*models.TaxSettings, error) {
	var cfg models.TaxSettings
	if err := s.getJSONSetting(companyID, "tax", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (s *SettingsService) UpdateTaxSettings(companyID int, cfg models.TaxSettings) error {
	return s.updateJSONSetting(companyID, "tax", cfg)
}

// Device control settings
func (s *SettingsService) GetDeviceControlSettings(companyID int) (*models.DeviceControlSettings, error) {
	var cfg models.DeviceControlSettings
	if err := s.getJSONSetting(companyID, "device_control", &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (s *SettingsService) UpdateDeviceControlSettings(companyID int, cfg models.DeviceControlSettings) error {
    return s.updateJSONSetting(companyID, "device_control", cfg)
}

// ensureSettingsPermissions inserts required settings permissions and assigns
// them to common roles if missing. This is idempotent and safe to call at startup.
func (s *SettingsService) ensureSettingsPermissions() error {
    // Insert permissions if missing
    if _, err := s.db.Exec(`
        INSERT INTO permissions (name, description, module, action)
        VALUES ('VIEW_SETTINGS','View settings','settings','view')
        ON CONFLICT (name) DO NOTHING
    `); err != nil {
        return fmt.Errorf("failed to ensure VIEW_SETTINGS: %w", err)
    }
    if _, err := s.db.Exec(`
        INSERT INTO permissions (name, description, module, action)
        VALUES ('MANAGE_SETTINGS','Manage settings','settings','manage')
        ON CONFLICT (name) DO NOTHING
    `); err != nil {
        return fmt.Errorf("failed to ensure MANAGE_SETTINGS: %w", err)
    }

    // Assign to Super Admin (1) and Admin (2) by default (idempotent)
    if _, err := s.db.Exec(`
        INSERT INTO role_permissions (role_id, permission_id)
        SELECT 1, p.permission_id FROM permissions p WHERE p.name IN ('VIEW_SETTINGS','MANAGE_SETTINGS')
        ON CONFLICT (role_id, permission_id) DO NOTHING
    `); err != nil {
        return fmt.Errorf("failed to grant settings perms to role 1: %w", err)
    }
    if _, err := s.db.Exec(`
        INSERT INTO role_permissions (role_id, permission_id)
        SELECT 2, p.permission_id FROM permissions p WHERE p.name IN ('VIEW_SETTINGS','MANAGE_SETTINGS')
        ON CONFLICT (role_id, permission_id) DO NOTHING
    `); err != nil {
        return fmt.Errorf("failed to grant settings perms to role 2: %w", err)
    }
    if _, err := s.db.Exec(`
        INSERT INTO role_permissions (role_id, permission_id)
        SELECT 3, p.permission_id FROM permissions p WHERE p.name = 'MANAGE_SETTINGS'
        ON CONFLICT (role_id, permission_id) DO NOTHING
    `); err != nil {
        return fmt.Errorf("failed to grant MANAGE_SETTINGS to role 3: %w", err)
    }
    // At least allow viewing settings for common roles (Manager=3, Sales=4, Store=5)
    if _, err := s.db.Exec(`
        INSERT INTO role_permissions (role_id, permission_id)
        SELECT r.role_id, p.permission_id
        FROM permissions p
        JOIN (VALUES (3),(4),(5)) AS r(role_id) ON TRUE
        WHERE p.name = 'VIEW_SETTINGS'
        ON CONFLICT (role_id, permission_id) DO NOTHING
    `); err != nil {
        return fmt.Errorf("failed to grant VIEW_SETTINGS to roles 3-5: %w", err)
    }
    return nil
}

// Payment methods CRUD
func (s *SettingsService) GetPaymentMethods(companyID int) ([]models.PaymentMethod, error) {
	rows, err := s.db.Query(`SELECT method_id, company_id, name, type, external_integration, is_active FROM payment_methods WHERE company_id=$1`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get payment methods: %w", err)
	}
	defer rows.Close()

	var methods []models.PaymentMethod
	for rows.Next() {
		var m models.PaymentMethod
		var ext models.JSONB
		var cid int
		if err := rows.Scan(&m.MethodID, &cid, &m.Name, &m.Type, &ext, &m.IsActive); err != nil {
			return nil, fmt.Errorf("failed to scan payment method: %w", err)
		}
		m.CompanyID = &cid
		m.ExternalIntegration = &ext
		methods = append(methods, m)
	}
	return methods, nil
}

func (s *SettingsService) CreatePaymentMethod(companyID int, req *models.PaymentMethodRequest) (*models.PaymentMethod, error) {
	row := s.db.QueryRow(`INSERT INTO payment_methods (company_id, name, type, external_integration, is_active) VALUES ($1,$2,$3,$4,$5) RETURNING method_id, name, type, external_integration, is_active`, companyID, req.Name, req.Type, req.ExternalIntegration, req.IsActive)
	var pm models.PaymentMethod
	var ext models.JSONB
	if err := row.Scan(&pm.MethodID, &pm.Name, &pm.Type, &ext, &pm.IsActive); err != nil {
		return nil, fmt.Errorf("failed to create payment method: %w", err)
	}
	pm.CompanyID = &companyID
	pm.ExternalIntegration = &ext
	return &pm, nil
}

func (s *SettingsService) UpdatePaymentMethod(companyID, id int, req *models.PaymentMethodRequest) error {
	_, err := s.db.Exec(`UPDATE payment_methods SET name=$1, type=$2, external_integration=$3, is_active=$4 WHERE method_id=$5 AND company_id=$6`, req.Name, req.Type, req.ExternalIntegration, req.IsActive, id, companyID)
	if err != nil {
		return fmt.Errorf("failed to update payment method: %w", err)
	}
	return nil
}

func (s *SettingsService) DeletePaymentMethod(companyID, id int) error {
	_, err := s.db.Exec(`DELETE FROM payment_methods WHERE method_id=$1 AND company_id=$2`, id, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete payment method: %w", err)
	}
	return nil
}

// Printer profiles CRUD
func (s *SettingsService) GetPrinters(companyID int) ([]models.PrinterProfile, error) {
	rows, err := s.db.Query(`SELECT printer_id, company_id, location_id, name, printer_type, paper_size, connectivity, is_default, is_active FROM printer_settings WHERE company_id=$1`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get printers: %w", err)
	}
	defer rows.Close()

	var printers []models.PrinterProfile
	for rows.Next() {
		var p models.PrinterProfile
		var conn models.JSONB
		if err := rows.Scan(&p.PrinterID, &p.CompanyID, &p.LocationID, &p.Name, &p.PrinterType, &p.PaperSize, &conn, &p.IsDefault, &p.IsActive); err != nil {
			return nil, fmt.Errorf("failed to scan printer: %w", err)
		}
		p.Connectivity = &conn
		printers = append(printers, p)
	}
	return printers, nil
}

func (s *SettingsService) CreatePrinter(companyID int, req *models.PrinterProfile) (*models.PrinterProfile, error) {
	row := s.db.QueryRow(`INSERT INTO printer_settings (company_id, location_id, name, printer_type, paper_size, connectivity, is_default, is_active) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING printer_id`, companyID, req.LocationID, req.Name, req.PrinterType, req.PaperSize, req.Connectivity, req.IsDefault, req.IsActive)
	if err := row.Scan(&req.PrinterID); err != nil {
		return nil, fmt.Errorf("failed to create printer: %w", err)
	}
	req.CompanyID = companyID
	return req, nil
}

func (s *SettingsService) UpdatePrinter(companyID, id int, req *models.PrinterProfile) error {
	_, err := s.db.Exec(`UPDATE printer_settings SET location_id=$1, name=$2, printer_type=$3, paper_size=$4, connectivity=$5, is_default=$6, is_active=$7 WHERE printer_id=$8 AND company_id=$9`, req.LocationID, req.Name, req.PrinterType, req.PaperSize, req.Connectivity, req.IsDefault, req.IsActive, id, companyID)
	if err != nil {
		return fmt.Errorf("failed to update printer: %w", err)
	}
	return nil
}

func (s *SettingsService) DeletePrinter(companyID, id int) error {
	_, err := s.db.Exec(`DELETE FROM printer_settings WHERE printer_id=$1 AND company_id=$2`, id, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete printer: %w", err)
	}
	return nil
}
