package services

import (
	"fmt"
	"log"

	"erp-backend/internal/config"
	"erp-backend/internal/models"
)

// PrintService provides printing capabilities
// It applies printer profiles and templates before dispatching the job
type PrintService struct {
	settingsService        *SettingsService
	invoiceTemplateService *InvoiceTemplateService
	cfg                    *config.Config
}

func NewPrintService() *PrintService {
	return &PrintService{
		settingsService:        NewSettingsService(),
		invoiceTemplateService: NewInvoiceTemplateService(),
		cfg:                    config.Load(),
	}
}

// PrintReceipt handles printing a receipt for a given reference
// It loads printer settings and invoice templates before sending to printer
func (s *PrintService) PrintReceipt(printType string, referenceID int, companyID int) error {
	if referenceID == 0 {
		return fmt.Errorf("invalid reference id")
	}

	// Fetch printer configuration
	printers, err := s.settingsService.GetPrinters(companyID)
	if err != nil {
		return fmt.Errorf("failed to load printers: %w", err)
	}
	var printer *models.PrinterProfile
	for i := range printers {
		if printers[i].IsDefault {
			printer = &printers[i]
			break
		}
	}
	if printer == nil && len(printers) > 0 {
		printer = &printers[0]
	}
	if printer == nil {
		// fallback to config if provided
		log.Printf("no printer configured in DB, using fallback %s", s.cfg.DefaultPrinter)
	}

	// Fetch template
	templates, err := s.invoiceTemplateService.GetInvoiceTemplates(companyID)
	if err != nil {
		return fmt.Errorf("failed to load templates: %w", err)
	}
	var template *models.InvoiceTemplate
	for i := range templates {
		if templates[i].TemplateType == printType && templates[i].IsDefault {
			template = &templates[i]
			break
		}
	}
	if template == nil {
		for i := range templates {
			if templates[i].TemplateType == printType {
				template = &templates[i]
				break
			}
		}
	}
	if template == nil {
		return fmt.Errorf("no template found for type %s", printType)
	}

	// Simulate printing
	printerName := s.cfg.DefaultPrinter
	if printer != nil {
		printerName = printer.Name
	}
	log.Printf("Printing %s %d using printer %s and template %s (path: %s)", printType, referenceID, printerName, template.Name, s.cfg.TemplatePath)
	return nil
}
