package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type InvoiceTemplateService struct {
	db *sql.DB
}

func NewInvoiceTemplateService() *InvoiceTemplateService {
	return &InvoiceTemplateService{db: database.GetDB()}
}

func (s *InvoiceTemplateService) GetInvoiceTemplates(companyID int) ([]models.InvoiceTemplate, error) {
	rows, err := s.db.Query(`SELECT template_id, company_id, name, template_type, layout, primary_language, secondary_language, is_default, is_active, created_at FROM invoice_templates WHERE company_id = $1 ORDER BY name`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get invoice templates: %w", err)
	}
	defer rows.Close()

	var templates []models.InvoiceTemplate
	for rows.Next() {
		var t models.InvoiceTemplate
		if err := rows.Scan(&t.TemplateID, &t.CompanyID, &t.Name, &t.TemplateType, &t.Layout, &t.PrimaryLanguage, &t.SecondaryLanguage, &t.IsDefault, &t.IsActive, &t.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan invoice template: %w", err)
		}
		templates = append(templates, t)
	}
	return templates, nil
}

func (s *InvoiceTemplateService) GetInvoiceTemplateByID(id, companyID int) (*models.InvoiceTemplate, error) {
	var t models.InvoiceTemplate
	err := s.db.QueryRow(`SELECT template_id, company_id, name, template_type, layout, primary_language, secondary_language, is_default, is_active, created_at FROM invoice_templates WHERE template_id = $1 AND company_id = $2`, id, companyID).Scan(&t.TemplateID, &t.CompanyID, &t.Name, &t.TemplateType, &t.Layout, &t.PrimaryLanguage, &t.SecondaryLanguage, &t.IsDefault, &t.IsActive, &t.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("invoice template not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get invoice template: %w", err)
	}
	return &t, nil
}

func (s *InvoiceTemplateService) CreateInvoiceTemplate(req *models.CreateInvoiceTemplateRequest) (*models.InvoiceTemplate, error) {
	exists, err := s.checkCompanyExists(req.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("failed to check company existence: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("company not found")
	}

	var t models.InvoiceTemplate
	err = s.db.QueryRow(`INSERT INTO invoice_templates (company_id, name, template_type, layout, primary_language, secondary_language, is_default, is_active) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING template_id, created_at`, req.CompanyID, req.Name, req.TemplateType, req.Layout, req.PrimaryLanguage, req.SecondaryLanguage, req.IsDefault, req.IsActive).Scan(&t.TemplateID, &t.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create invoice template: %w", err)
	}

	t.CompanyID = req.CompanyID
	t.Name = req.Name
	t.TemplateType = req.TemplateType
	t.Layout = req.Layout
	t.PrimaryLanguage = req.PrimaryLanguage
	t.SecondaryLanguage = req.SecondaryLanguage
	t.IsDefault = req.IsDefault
	t.IsActive = req.IsActive
	return &t, nil
}

func (s *InvoiceTemplateService) UpdateInvoiceTemplate(id, companyID int, req *models.UpdateInvoiceTemplateRequest) error {
	setParts := []string{}
	args := []interface{}{}

	if req.Name != nil {
		setParts = append(setParts, fmt.Sprintf("name = $%d", len(args)+1))
		args = append(args, *req.Name)
	}
	if req.TemplateType != nil {
		setParts = append(setParts, fmt.Sprintf("template_type = $%d", len(args)+1))
		args = append(args, *req.TemplateType)
	}
	if req.Layout != nil {
		setParts = append(setParts, fmt.Sprintf("layout = $%d", len(args)+1))
		args = append(args, *req.Layout)
	}
	if req.PrimaryLanguage != nil {
		setParts = append(setParts, fmt.Sprintf("primary_language = $%d", len(args)+1))
		args = append(args, *req.PrimaryLanguage)
	}
	if req.SecondaryLanguage != nil {
		setParts = append(setParts, fmt.Sprintf("secondary_language = $%d", len(args)+1))
		args = append(args, *req.SecondaryLanguage)
	}
	if req.IsDefault != nil {
		setParts = append(setParts, fmt.Sprintf("is_default = $%d", len(args)+1))
		args = append(args, *req.IsDefault)
	}
	if req.IsActive != nil {
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", len(args)+1))
		args = append(args, *req.IsActive)
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	argPos := len(args) + 1
	query := fmt.Sprintf("UPDATE invoice_templates SET %s WHERE template_id = $%d AND company_id = $%d", strings.Join(setParts, ", "), argPos, argPos+1)
	args = append(args, id, companyID)

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update invoice template: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("invoice template not found")
	}
	return nil
}

func (s *InvoiceTemplateService) DeleteInvoiceTemplate(id, companyID int) error {
	result, err := s.db.Exec(`DELETE FROM invoice_templates WHERE template_id = $1 AND company_id = $2`, id, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete invoice template: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("invoice template not found")
	}
	return nil
}

func (s *InvoiceTemplateService) checkCompanyExists(companyID int) (bool, error) {
	var count int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM companies WHERE company_id = $1 AND is_active = TRUE`, companyID).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}
