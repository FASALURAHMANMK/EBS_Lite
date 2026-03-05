package services

import (
	"database/sql"
	"fmt"
	"hash/fnv"
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

type lockedSequence struct {
	seqID   int
	prefix  sql.NullString
	seqLen  int
	current int
}

func advisoryLockKey(companyID int, locationID *int, sequenceName string) int64 {
	h := fnv.New64a()
	_, _ = h.Write([]byte(sequenceName))
	_, _ = h.Write([]byte{0})
	_, _ = h.Write([]byte(fmt.Sprintf("%d", companyID)))
	_, _ = h.Write([]byte{0})
	if locationID != nil {
		_, _ = h.Write([]byte(fmt.Sprintf("%d", *locationID)))
	}
	return int64(h.Sum64())
}

func (s *NumberingSequenceService) lockOrCreateSequence(tx *sql.Tx, sequenceName string, companyID int, locationID *int) (*lockedSequence, error) {
	// Serialize first-use provisioning of this sequence to avoid duplicate rows when the sequence doesn't exist yet.
	if _, err := tx.Exec(`SELECT pg_advisory_xact_lock($1)`, advisoryLockKey(companyID, locationID, sequenceName)); err != nil {
		return nil, fmt.Errorf("failed to lock sequence allocation: %w", err)
	}

	selectSeq := func(q string, args ...interface{}) (*lockedSequence, error) {
		var ls lockedSequence
		if err := tx.QueryRow(q, args...).Scan(&ls.seqID, &ls.prefix, &ls.seqLen, &ls.current); err != nil {
			return nil, err
		}
		return &ls, nil
	}

	// Prefer a location-specific sequence when location is known; fall back to global (NULL location_id).
	if locationID != nil {
		ls, err := selectSeq(
			`SELECT sequence_id, prefix, sequence_length, current_number
			   FROM numbering_sequences
			  WHERE name = $1 AND company_id = $2 AND location_id = $3
			  ORDER BY sequence_id DESC
			  FOR UPDATE`,
			sequenceName, companyID, *locationID,
		)
		if err == nil {
			return ls, nil
		}
		if err != sql.ErrNoRows {
			return nil, fmt.Errorf("failed to get numbering sequence: %w", err)
		}

		ls, err = selectSeq(
			`SELECT sequence_id, prefix, sequence_length, current_number
			   FROM numbering_sequences
			  WHERE name = $1 AND company_id = $2 AND location_id IS NULL
			  ORDER BY sequence_id DESC
			  FOR UPDATE`,
			sequenceName, companyID,
		)
		if err == nil {
			return ls, nil
		}
		if err != sql.ErrNoRows {
			return nil, fmt.Errorf("failed to get numbering sequence: %w", err)
		}
	} else {
		ls, err := selectSeq(
			`SELECT sequence_id, prefix, sequence_length, current_number
			   FROM numbering_sequences
			  WHERE name = $1 AND company_id = $2 AND location_id IS NULL
			  ORDER BY sequence_id DESC
			  FOR UPDATE`,
			sequenceName, companyID,
		)
		if err == nil {
			return ls, nil
		}
		if err != sql.ErrNoRows {
			return nil, fmt.Errorf("failed to get numbering sequence: %w", err)
		}
	}

	// Auto-provision a default sequence if none exists for this company/location.
	defPrefix := defaultPrefixFor(sequenceName)
	var locArg interface{}
	if locationID != nil {
		locArg = *locationID
	} else {
		locArg = nil
	}
	if _, insErr := tx.Exec(
		`INSERT INTO numbering_sequences (company_id, location_id, name, prefix, sequence_length, current_number)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		companyID, locArg, sequenceName, defPrefix, 6, 0,
	); insErr != nil {
		return nil, fmt.Errorf("failed to create default numbering sequence: %w", insErr)
	}

	// Re-fetch with lock after create.
	if locationID != nil {
		ls, err := selectSeq(
			`SELECT sequence_id, prefix, sequence_length, current_number
			   FROM numbering_sequences
			  WHERE name = $1 AND company_id = $2 AND location_id = $3
			  ORDER BY sequence_id DESC
			  FOR UPDATE`,
			sequenceName, companyID, *locationID,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to get numbering sequence after create: %w", err)
		}
		return ls, nil
	}
	ls, err := selectSeq(
		`SELECT sequence_id, prefix, sequence_length, current_number
		   FROM numbering_sequences
		  WHERE name = $1 AND company_id = $2 AND location_id IS NULL
		  ORDER BY sequence_id DESC
		  FOR UPDATE`,
		sequenceName, companyID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get numbering sequence after create: %w", err)
	}
	return ls, nil
}

// NextNumber retrieves the next formatted number for the given sequence and
// persists the incremented value within the provided transaction. It locks the
// sequence row using FOR UPDATE to ensure atomicity across concurrent calls.
func (s *NumberingSequenceService) NextNumber(tx *sql.Tx, sequenceName string, companyID int, locationID *int) (string, error) {
	ls, err := s.lockOrCreateSequence(tx, sequenceName, companyID, locationID)
	if err != nil {
		return "", err
	}

	ls.current++
	if _, err := tx.Exec(`UPDATE numbering_sequences SET current_number = $1, updated_at = CURRENT_TIMESTAMP WHERE sequence_id = $2`, ls.current, ls.seqID); err != nil {
		return "", fmt.Errorf("failed to update numbering sequence: %w", err)
	}

	prefixStr := ""
	if ls.prefix.Valid {
		prefixStr = ls.prefix.String
	}

	return fmt.Sprintf("%s%0*d", prefixStr, ls.seqLen, ls.current), nil
}

// ReserveNumberBlock atomically reserves a contiguous range of numbers for offline use.
// The range is inclusive: [start, end].
func (s *NumberingSequenceService) ReserveNumberBlock(sequenceName string, companyID int, locationID *int, blockSize int) (*models.ReserveNumberBlockResponse, error) {
	sequenceName = strings.TrimSpace(sequenceName)
	if sequenceName == "" {
		return nil, fmt.Errorf("sequence name is required")
	}
	if blockSize <= 0 {
		blockSize = 50
	}
	if blockSize > 500 {
		blockSize = 500
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	ls, err := s.lockOrCreateSequence(tx, sequenceName, companyID, locationID)
	if err != nil {
		return nil, err
	}

	start := ls.current + 1
	end := ls.current + blockSize

	if _, err := tx.Exec(`UPDATE numbering_sequences SET current_number = $1, updated_at = CURRENT_TIMESTAMP WHERE sequence_id = $2`, end, ls.seqID); err != nil {
		return nil, fmt.Errorf("failed to update numbering sequence: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit reservation: %w", err)
	}

	prefixStr := ""
	if ls.prefix.Valid {
		prefixStr = ls.prefix.String
	}

	return &models.ReserveNumberBlockResponse{
		SequenceName:    sequenceName,
		Prefix:          prefixStr,
		SequenceLength:  ls.seqLen,
		StartNumber:     start,
		EndNumber:       end,
		CurrentNumberDB: end,
	}, nil
}

// defaultPrefixFor returns a sane default prefix for a given sequence name.
// This helps auto-provision sequences on first use.
func defaultPrefixFor(name string) *string {
	n := strings.ToLower(strings.TrimSpace(name))
	var p string
	switch n {
	case "sale":
		p = "INV-"
	case "sale_training":
		p = "TRN-"
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
