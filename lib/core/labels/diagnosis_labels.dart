import 'status_label.dart';

// What the farmer sees of a diagnosis case. Every stage before the reviewer's decision is one "waiting" state: the AI's
// own answer is evidence for the reviewer and is never shown (AI_DIAGNOSIS.md D8).

const _waiting = StatusLabel('Đang chờ chuyên viên xem', LabelTone.pending);

const diagnosisStatusLabels = <String, StatusLabel>{
  'SUBMITTED': _waiting,
  'PROCESSING': _waiting,
  'AI_COMPLETED': _waiting,
  'UNDER_REVIEW': _waiting,
  'FAILED': _waiting,
  'VERIFIED': StatusLabel('Đã có kết quả', LabelTone.success),
  'INCONCLUSIVE': StatusLabel('Cần chụp lại ảnh', LabelTone.progress),
  'CANCELLED': StatusLabel('Đã hủy', LabelTone.neutral),
};

/// Names of the five classes in words a farmer uses. The server's own `name` is used for anything else.
const _diseaseNames = <String, String>{
  'LEAF_BLAST': 'Bệnh đạo ôn',
  'BACTERIAL_LEAF_BLIGHT': 'Bệnh bạc lá (cháy bìa lá)',
  'BROWN_SPOT': 'Bệnh đốm nâu',
  'SHEATH_BLIGHT': 'Bệnh khô vằn',
  'HEALTHY': 'Lá lúa khỏe mạnh',
};

String diseaseDisplayName(String? code, {String? fallback}) {
  if (code != null && _diseaseNames.containsKey(code)) return _diseaseNames[code]!;
  return (fallback != null && fallback.isNotEmpty) ? fallback : (code ?? '—');
}

const treatmentTypeLabels = <String, String>{
  'CULTURAL': 'Canh tác',
  'CHEMICAL': 'Thuốc / hóa chất',
  'PREVENTIVE': 'Phòng ngừa',
  'OTHER': 'Khác',
};

String treatmentTypeLabel(String type) => treatmentTypeLabels[type] ?? type;
