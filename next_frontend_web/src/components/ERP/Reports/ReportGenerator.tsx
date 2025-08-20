import React, { useState, useEffect } from 'react';
import api from '../../../services/apiClient';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';
import * as XLSX from 'xlsx';

interface Column {
  key: string;
  label: string;
}

interface ReportGeneratorProps {
  title: string;
  endpoint: string;
  columns: Column[];
  filename: string;
  dateField?: string;
}

const ReportGenerator: React.FC<ReportGeneratorProps> = ({
  title,
  endpoint,
  columns,
  filename,
  dateField = 'date'
}) => {
  const [data, setData] = useState<any[]>([]);
  const [filtered, setFiltered] = useState<any[]>([]);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  useEffect(() => {
    const loadData = async () => {
      try {
        const res = await api.get<any[]>(endpoint);
        setData(res);
        setFiltered(res);
      } catch (err) {
        console.error('Failed to load report data', err);
      }
    };
    loadData();
  }, [endpoint]);

  const handleFilter = () => {
    let result = data;
    if (startDate) {
      result = result.filter(item => new Date(item[dateField]) >= new Date(startDate));
    }
    if (endDate) {
      result = result.filter(item => new Date(item[dateField]) <= new Date(endDate));
    }
    setFiltered(result);
  };

  const exportExcel = () => {
    const ws = XLSX.utils.json_to_sheet(filtered);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Report');
    XLSX.writeFile(wb, `${filename}.xlsx`);
  };

  const exportPdf = () => {
    const doc = new jsPDF();
    const tableColumn = columns.map(c => c.label);
    const tableRows = filtered.map(row => columns.map(c => row[c.key]));
    autoTable(doc, { head: [tableColumn], body: tableRows });
    doc.save(`${filename}.pdf`);
  };

  return (
    <div className="p-6 bg-gray-50 dark:bg-gray-950 min-h-full">
      <h1 className="text-2xl font-bold text-gray-800 dark:text-white mb-4">{title}</h1>
      <div className="flex items-end space-x-4 mb-4">
        <div>
          <label className="block text-sm text-gray-700 dark:text-gray-300 mb-1">From</label>
          <input
            type="date"
            value={startDate}
            onChange={e => setStartDate(e.target.value)}
            className="border rounded px-2 py-1 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-200"
          />
        </div>
        <div>
          <label className="block text-sm text-gray-700 dark:text-gray-300 mb-1">To</label>
          <input
            type="date"
            value={endDate}
            onChange={e => setEndDate(e.target.value)}
            className="border rounded px-2 py-1 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-200"
          />
        </div>
        <button
          onClick={handleFilter}
          className="bg-red-600 text-white px-4 py-2 rounded"
        >
          Filter
        </button>
        <button
          onClick={exportPdf}
          className="bg-blue-600 text-white px-4 py-2 rounded"
        >
          Export PDF
        </button>
        <button
          onClick={exportExcel}
          className="bg-green-600 text-white px-4 py-2 rounded"
        >
          Export Excel
        </button>
      </div>
      <div className="overflow-x-auto">
        <table id="report-table" className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-100 dark:bg-gray-800">
            <tr>
              {columns.map(col => (
                <th key={col.key} className="px-4 py-2 text-left text-sm font-medium text-gray-700 dark:text-gray-300">
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
            {filtered.map((row, idx) => (
              <tr key={idx}>
                {columns.map(col => (
                  <td key={col.key} className="px-4 py-2 text-sm text-gray-700 dark:text-gray-300">
                    {row[col.key]}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default ReportGenerator;
