package main

import (
	"flag"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

type route struct {
	Method string
	Path   string
}

type scopeStack struct {
	scopes []map[string]string
}

func (s *scopeStack) push() {
	s.scopes = append(s.scopes, map[string]string{})
}

func (s *scopeStack) pop() {
	if len(s.scopes) == 0 {
		return
	}
	s.scopes = s.scopes[:len(s.scopes)-1]
}

func (s *scopeStack) set(name, prefix string) {
	if len(s.scopes) == 0 {
		s.push()
	}
	s.scopes[len(s.scopes)-1][name] = prefix
}

func (s *scopeStack) get(name string) (string, bool) {
	for i := len(s.scopes) - 1; i >= 0; i-- {
		if v, ok := s.scopes[i][name]; ok {
			return v, true
		}
	}
	return "", false
}

func normalizePath(p string) string {
	if p == "" {
		return "/"
	}
	if !strings.HasPrefix(p, "/") {
		p = "/" + p
	}
	for strings.Contains(p, "//") {
		p = strings.ReplaceAll(p, "//", "/")
	}
	if len(p) > 1 {
		p = strings.TrimRight(p, "/")
	}
	return p
}

func joinPath(prefix, suffix string) string {
	prefix = strings.TrimRight(prefix, "/")
	suffix = strings.TrimLeft(suffix, "/")
	if prefix == "" && suffix == "" {
		return "/"
	}
	if prefix == "" {
		return normalizePath("/" + suffix)
	}
	if suffix == "" {
		return normalizePath(prefix)
	}
	return normalizePath(prefix + "/" + suffix)
}

func unquoteStringLit(expr ast.Expr) (string, bool) {
	lit, ok := expr.(*ast.BasicLit)
	if !ok || lit.Kind != token.STRING {
		return "", false
	}
	val, err := strconv.Unquote(lit.Value)
	if err != nil {
		return "", false
	}
	return val, true
}

func receiverIdent(call *ast.CallExpr) (string, string, bool) {
	sel, ok := call.Fun.(*ast.SelectorExpr)
	if !ok {
		return "", "", false
	}
	id, ok := sel.X.(*ast.Ident)
	if !ok {
		return "", "", false
	}
	return id.Name, sel.Sel.Name, true
}

func findInitializeFunc(file *ast.File) (*ast.FuncDecl, bool) {
	for _, d := range file.Decls {
		fd, ok := d.(*ast.FuncDecl)
		if !ok || fd.Name == nil || fd.Name.Name != "Initialize" {
			continue
		}
		if fd.Body == nil {
			return nil, false
		}
		return fd, true
	}
	return nil, false
}

func walkStmt(stmt ast.Stmt, scopes *scopeStack, routes *[]route) {
	switch s := stmt.(type) {
	case *ast.BlockStmt:
		scopes.push()
		for _, st := range s.List {
			walkStmt(st, scopes, routes)
		}
		scopes.pop()
	case *ast.AssignStmt:
		// Capture: x := y.Group("/prefix")
		for i := range s.Lhs {
			lhs, ok := s.Lhs[i].(*ast.Ident)
			if !ok {
				continue
			}
			if i >= len(s.Rhs) {
				continue
			}
			call, ok := s.Rhs[i].(*ast.CallExpr)
			if !ok {
				continue
			}
			recv, method, ok := receiverIdent(call)
			if !ok || method != "Group" {
				continue
			}
			if len(call.Args) < 1 {
				continue
			}
			groupPath, ok := unquoteStringLit(call.Args[0])
			if !ok {
				continue
			}
			parentPrefix, ok := scopes.get(recv)
			if !ok {
				continue
			}
			scopes.set(lhs.Name, joinPath(parentPrefix, groupPath))
		}
	case *ast.DeclStmt:
		// Handle: var x = y.Group("/prefix") (rare here, but deterministic)
		gen, ok := s.Decl.(*ast.GenDecl)
		if !ok || gen.Tok != token.VAR {
			return
		}
		for _, spec := range gen.Specs {
			vs, ok := spec.(*ast.ValueSpec)
			if !ok {
				continue
			}
			for i := range vs.Names {
				if i >= len(vs.Values) {
					continue
				}
				call, ok := vs.Values[i].(*ast.CallExpr)
				if !ok {
					continue
				}
				recv, method, ok := receiverIdent(call)
				if !ok || method != "Group" {
					continue
				}
				if len(call.Args) < 1 {
					continue
				}
				groupPath, ok := unquoteStringLit(call.Args[0])
				if !ok {
					continue
				}
				parentPrefix, ok := scopes.get(recv)
				if !ok {
					continue
				}
				scopes.set(vs.Names[i].Name, joinPath(parentPrefix, groupPath))
			}
		}
	case *ast.ExprStmt:
		call, ok := s.X.(*ast.CallExpr)
		if ok {
			walkCall(call, scopes, routes)
		}
	case *ast.IfStmt:
		if s.Init != nil {
			walkStmt(s.Init, scopes, routes)
		}
		if s.Body != nil {
			walkStmt(s.Body, scopes, routes)
		}
		if s.Else != nil {
			walkStmt(s.Else, scopes, routes)
		}
	case *ast.ForStmt:
		if s.Init != nil {
			walkStmt(s.Init, scopes, routes)
		}
		if s.Body != nil {
			walkStmt(s.Body, scopes, routes)
		}
	case *ast.RangeStmt:
		if s.Body != nil {
			walkStmt(s.Body, scopes, routes)
		}
	case *ast.SwitchStmt:
		if s.Init != nil {
			walkStmt(s.Init, scopes, routes)
		}
		if s.Body != nil {
			walkStmt(s.Body, scopes, routes)
		}
	case *ast.TypeSwitchStmt:
		if s.Init != nil {
			walkStmt(s.Init, scopes, routes)
		}
		if s.Body != nil {
			walkStmt(s.Body, scopes, routes)
		}
	case *ast.CaseClause:
		scopes.push()
		for _, st := range s.Body {
			walkStmt(st, scopes, routes)
		}
		scopes.pop()
	}
}

func walkCall(call *ast.CallExpr, scopes *scopeStack, routes *[]route) {
	recv, method, ok := receiverIdent(call)
	if !ok {
		return
	}

	httpMethods := map[string]bool{
		"GET":     true,
		"POST":    true,
		"PUT":     true,
		"DELETE":  true,
		"PATCH":   true,
		"HEAD":    true,
		"OPTIONS": true,
	}
	if !httpMethods[method] {
		return
	}
	if len(call.Args) < 1 {
		return
	}
	routePath, ok := unquoteStringLit(call.Args[0])
	if !ok {
		return
	}
	prefix, ok := scopes.get(recv)
	if !ok {
		return
	}
	*routes = append(*routes, route{
		Method: method,
		Path:   joinPath(prefix, routePath),
	})
}

func resolveDefaultInputPath(in string) string {
	if in != "" {
		return in
	}
	candidates := []string{
		filepath.FromSlash("internal/routes/routes.go"),
		filepath.FromSlash("go_backend_rmt/internal/routes/routes.go"),
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return candidates[0]
}

func main() {
	var in string
	var out string
	flag.StringVar(&in, "in", "", "Path to go_backend_rmt/internal/routes/routes.go")
	flag.StringVar(&out, "out", "", "Write output to this file (optional)")
	flag.Parse()

	in = resolveDefaultInputPath(in)
	fset := token.NewFileSet()
	parsed, err := parser.ParseFile(fset, in, nil, 0)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to parse %s: %v\n", in, err)
		os.Exit(2)
	}

	initFn, ok := findInitializeFunc(parsed)
	if !ok {
		fmt.Fprintf(os.Stderr, "Initialize() not found in %s\n", in)
		os.Exit(2)
	}

	scopes := &scopeStack{}
	scopes.push()
	if initFn.Type != nil && initFn.Type.Params != nil && len(initFn.Type.Params.List) > 0 {
		if len(initFn.Type.Params.List[0].Names) > 0 {
			scopes.set(initFn.Type.Params.List[0].Names[0].Name, "")
		}
	}

	var routesFound []route
	walkStmt(initFn.Body, scopes, &routesFound)

	uniq := map[string]route{}
	for _, r := range routesFound {
		key := r.Method + " " + r.Path
		uniq[key] = r
	}

	lines := make([]string, 0, len(uniq))
	for k := range uniq {
		lines = append(lines, k)
	}
	sort.Strings(lines)
	content := strings.Join(lines, "\n") + "\n"

	fmt.Print(content)
	if out != "" {
		if err := os.WriteFile(out, []byte(content), 0o644); err != nil {
			fmt.Fprintf(os.Stderr, "failed to write %s: %v\n", out, err)
			os.Exit(2)
		}
	}
}
