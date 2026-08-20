/// The code + file fields an answer or a challenge attempt can carry.
///
/// One type for both, mirroring `CodeSubmission` in
/// `server/app/schemas/code.py`. An empty instance means "no code was
/// submitted", which is the normal case for a prose answer.
class CodeSubmission {
  const CodeSubmission({
    this.codeBody,
    this.codeLanguage,
    this.attachmentUrl,
    this.attachmentName,
  });

  static const empty = CodeSubmission();

  final String? codeBody;
  final String? codeLanguage;
  final String? attachmentUrl;
  final String? attachmentName;

  bool get hasCode => (codeBody ?? '').trim().isNotEmpty;
  bool get hasAttachment => (attachmentUrl ?? '').isNotEmpty;
  bool get isEmpty => !hasCode && !hasAttachment;

  CodeSubmission copyWith({
    String? codeBody,
    String? codeLanguage,
    String? attachmentUrl,
    String? attachmentName,
    bool clearAttachment = false,
  }) =>
      CodeSubmission(
        codeBody: codeBody ?? this.codeBody,
        codeLanguage: codeLanguage ?? this.codeLanguage,
        attachmentUrl: clearAttachment ? '' : attachmentUrl ?? this.attachmentUrl,
        attachmentName:
            clearAttachment ? '' : attachmentName ?? this.attachmentName,
      );

  /// Only the fields that were actually set are sent. The server leaves an
  /// omitted field alone and clears one sent as `""`, which is how "I did not
  /// touch my code" stays distinct from "I removed it".
  Map<String, dynamic> toJson() => {
        if (codeBody != null) 'code_body': codeBody,
        if (codeLanguage != null) 'code_language': codeLanguage,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        if (attachmentName != null) 'attachment_name': attachmentName,
      };

  factory CodeSubmission.fromJson(Map<String, dynamic> json) => CodeSubmission(
        codeBody: json['code_body'] as String?,
        codeLanguage: json['code_language'] as String?,
        attachmentUrl: json['attachment_url'] as String?,
        attachmentName: json['attachment_name'] as String?,
      );
}
