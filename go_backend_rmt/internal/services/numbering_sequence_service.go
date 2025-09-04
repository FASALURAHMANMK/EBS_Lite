package services

import (
    "database/sql"
    "fmt"
    "strings"

    "erp-backend/internal/database"
    "erp-backend/internal/models"
)

type NumberingSequenceService struct {
	db *sql.DB
}

func NewNumberingSequenceService() *NumberingSequenceService {
	return &NumberingSequenceService{db: database.GetDB()}
}

func (s *NumberingSequenceService) GetNumberingSequences(companyID int, locationID *int) ([]models.NumberingSequence, error) {
	query := `SELECT sequence_id, company_id, location_id, name, prefix, sequence_length, current_number, created_at, updated_at FROM numbering_sequences WHERE company_id = $1`
	args := []interface{}{companyID}
	if locationID != nil {
		query += " AND (location_id = $2 OR location_id IS NULL)"
		args = append(args, *locationID)
	}
	query += " ORDER BY name"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get numbering sequences: %w", err)
	}
	defer rows.Close()

	var sequences []models.NumberingSequence
	for rows.Next() {
		var ns models.NumberingSequence
		if err := rows.Scan(&ns.SequenceID, &ns.CompanyID, &ns.LocationID, &ns.Name, &ns.Prefix, &ns.SequenceLength, &ns.CurrentNumber, &ns.CreatedAt, &ns.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan numbering sequence: %w", err)
		}
		sequences = append(sequences, ns)
	}
	return sequences, nil
}

func (s *NumberingSequenceService) GetNumberingSequenceByID(id, companyID int, locationID *int) (*models.NumberingSequence, error) {
	query := `SELECT sequence_id, company_id, location_id, name, prefix, sequence_length, current_number, created_at, updated_at FROM numbering_sequences WHERE sequence_id = $1 AND company_id = $2`
	args := []interface{}{id, companyID}
	if locationID != nil {
		query += " AND (location_id = $3 OR location_id IS NULL)"
		args = append(args, *locationID)
	}
	var ns models.NumberingSequence
	err := s.db.QueryRow(query, args...).Scan(&ns.SequenceID, &ns.CompanyID, &ns.LocationID, &ns.Name, &ns.Prefix, &ns.SequenceLength, &ns.CurrentNumber, &ns.CreatedAt, &ns.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("numbering sequence not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get numbering sequence: %w", err)
	}
	return &ns, nil
}

func (s *NumberingSequenceService) CreateNumberingSequence(req *models.CreateNumberingSequenceRequest) (*models.NumberingSequence, error) {
	exists, err := s.checkCompanyExists(req.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("failed to check company existence: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("company not found")
	}
	if req.LocationID != nil {
		ok, err := s.checkLocationBelongsToCompany(req.CompanyID, *req.LocationID)
		if err != nil {
			return nil, fmt.Errorf("failed to check location existence: %w", err)
		}
		if !ok {
			return nil, fmt.Errorf("location not found")
		}
	}

	start := 0
	if req.StartFrom != nil {
		start = *req.StartFrom
	}

	var ns models.NumberingSequence
	err = s.db.QueryRow(`INSERT INTO numbering_sequences (company_id, location_id, name, prefix, sequence_length, current_number) VALUES ($1,$2,$3,$4,$5,$6) RETURNING sequence_id, current_number, created_at, updated_at`, req.CompanyID, req.LocationID, req.Name, req.Prefix, req.SequenceLength, start).Scan(&ns.SequenceID, &ns.CurrentNumber, &ns.CreatedAt, &ns.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create numbering sequence: %w", err)
	}

	ns.CompanyID = req.CompanyID
	ns.LocationID = req.LocationID
	ns.Name = req.Name
	ns.Prefix = req.Prefix
	ns.SequenceLength = req.SequenceLength
	return &ns, nil
}

func (s *NumberingSequenceService) UpdateNumberingSequence(id, companyID int, locationID *int, req *models.UpdateNumberingSequenceRequest) error {
	setParts := []string{}
	args := []interface{}{}

	if req.Name != nil {
		setParts = append(setParts, fmt.Sprintf("name = $%d", len(args)+1))
		args = append(args, *req.Name)
	}
	if req.Prefix != nil {
		setParts = append(setParts, fmt.Sprintf("prefix = $%d", len(args)+1))
		args = append(args, *req.Prefix)
	}
	if req.SequenceLength != nil {
		setParts = append(setParts, fmt.Sprintf("sequence_length = $%d", len(args)+1))
		args = append(args, *req.SequenceLength)
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")
	argPos := len(args) + 1
	query := fmt.Sprintf("UPDATE numbering_sequences SET %s WHERE sequence_id = $%d AND company_id = $%d", strings.Join(setParts, ", "), argPos, argPos+1)
	args = append(args, id, companyID)
	if locationID != nil {
		query += fmt.Sprintf(" AND (location_id = $%d OR location_id IS NULL)", argPos+2)
		args = append(args, *locationID)
	}

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update numbering sequence: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("numbering sequence not found")
	}
	return nil
}

func (s *NumberingSequenceService) DeleteNumberingSequence(id, companyID int, locationID *int) error {
	query := "DELETE FROM numbering_sequences WHERE sequence_id = $1 AND company_id = $2"
	args := []interface{}{id, companyID}
	if locationID != nil {
		query += " AND (location_id = $3 OR location_id IS NULL)"
		args = append(args, *locationID)
	}
	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to delete numbering sequence: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("numbering sequence not found")
	}
	return nil
}

func (s *NumberingSequenceService) checkCompanyExists(companyID int) (bool, error) {
	var count int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM companies WHERE company_id = $1 AND is_active = TRUE`, companyID).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func (s *NumberingSequenceService) checkLocationBelongsToCompany(companyID, locationID int) (bool, error) {
	var count int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM locations WHERE location_id = $1 AND company_id = $2 AND is_active = TRUE`, locationID, companyID).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

// NextNumber retrieves the next formatted number for the given sequence and
// persists the incremented value within the provided transaction. It locks the
// sequence row using FOR UPDATE to ensure atomicity across concurrent calls.
func (s *NumberingSequenceService) NextNumber(tx *sql.Tx, sequenceName string, companyID int, locationID *int) (string, error) {
    // Build query to fetch sequence with row-level lock
    query := `SELECT sequence_id, prefix, sequence_length, current_number
                 FROM numbering_sequences
                 WHERE name = $1 AND company_id = $2`
    args := []interface{}{sequenceName, companyID}
    if locationID != nil {
        query += " AND (location_id = $3 OR location_id IS NULL)"
        args = append(args, *locationID)
    }
    query += " FOR UPDATE"

    var seqID, seqLen, current int
    var prefix sql.NullString
    if err := tx.QueryRow(query, args...).Scan(&seqID, &prefix, &seqLen, &current); err != nil {
        if err == sql.ErrNoRows {
            // Auto-provision a default sequence if none exists for this company/location
            // to prevent hard failures on first use.
            defPrefix := defaultPrefixFor(sequenceName)
            var locArg interface{}
            if locationID != nil {
                locArg = *locationID
            } else {
                locArg = nil
            }
            // Create with sensible defaults: length=6, start from 0
            if _, insErr := tx.Exec(
                `INSERT INTO numbering_sequences (company_id, location_id, name, prefix, sequence_length, current_number)
                 VALUES ($1, $2, $3, $4, $5, $6)`,
                companyID, locArg, sequenceName, defPrefix, 6, 0,
            ); insErr != nil {
                return "", fmt.Errorf("failed to create default numbering sequence: %w", insErr)
            }
            // Re-run the locked select now that a sequence exists
            if err := tx.QueryRow(query, args...).Scan(&seqID, &prefix, &seqLen, &current); err != nil {
                return "", fmt.Errorf("failed to get numbering sequence after create: %w", err)
            }
        } else {
            return "", fmt.Errorf("failed to get numbering sequence: %w", err)
        }
    }

	current++
    if _, err := tx.Exec(`UPDATE numbering_sequences SET current_number = $1, updated_at = CURRENT_TIMESTAMP WHERE sequence_id = $2`, current, seqID); err != nil {
        return "", fmt.Errorf("failed to update numbering sequence: %w", err)
    }

	prefixStr := ""
	if prefix.Valid {
		prefixStr = prefix.String
	}

    return fmt.Sprintf("%s%0*d", prefixStr, seqLen, current), nil
}

// defaultPrefixFor returns a sane default prefix for a given sequence name.
// This helps auto-provision sequences on first use.
func defaultPrefixFor(name string) *string {
    n := strings.ToLower(strings.TrimSpace(name))
    var p string
    switch n {
    case "sale":
        p = "INV-"
    case "quote":
        p = "QOT-"
    case "purchase":
        p = "PO-"
    case "sale_return":
        p = "SR-"
    case "purchase_return":
        p = "PR-"
    case "stock_adjustment":
        p = "ADJ-"
    case "stock_transfer":
        p = "ST-"
    default:
        // Use first 3 letters uppercased as a generic prefix
        up := strings.ToUpper(n)
        if len(up) > 3 {
            up = up[:3]
        }
        p = up + "-"
    }
    return &p
}
