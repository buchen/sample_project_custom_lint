import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _I18nLinter();

class _I18nLinter extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        I18NCustomLintCode(),
      ];
}

final _uriRegExp = RegExp(r'[/\\]');
bool _looksLikeUriOrPath(String value) => _uriRegExp.hasMatch(value);

final _testRegExp = RegExp(r'/(integration_)?test(_driver)?/');
bool _looksLikeTestFile(String value) => _testRegExp.hasMatch(value);

class I18NCustomLintCode extends DartLintRule {
  I18NCustomLintCode() : super(code: _code);

  static const _code = LintCode(
    name: 'non_externalized_string_literal',
    problemMessage: 'Non-externalized string literal found.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addStringLiteral((node) {
      if (node.stringValue == null) return;

      // ignore test files
      if (_looksLikeTestFile(resolver.source.fullName)) return;

      // ignore empty strings
      if (node.stringValue!.isEmpty) return;

      // ignore strings of length 1
      if (node.stringValue!.length == 1) return;

      // ignore if it looks like a URI or path
      if (_looksLikeUriOrPath(node.stringValue!)) return;

      // ignore if it starts with an underscore (used as identifier)
      if (node.stringValue!.startsWith('_')) return;

      // ignore if it starts with an hash (used for colors)
      if (node.stringValue!.startsWith('#')) return;

      if (node.thisOrAncestorOfType<ImportDirective>() != null) return;
      if (node.thisOrAncestorOfType<ExportDirective>() != null) return;
      if (node.thisOrAncestorOfType<PartDirective>() != null) return;
      if (node.thisOrAncestorOfType<PartOfDirective>() != null) return;

      if (_checkIfIgnoreToDueMethod(node)) return;

      reporter.reportErrorForNode(code, node);
    });

    context.registry.addStringInterpolation((node) {
      // ignore test files
      if (_looksLikeTestFile(resolver.source.fullName)) return;

      // collect a (pseudo) string value from the elements
      var stringValue = '';

      for (var element in node.elements) {
        if (element is InterpolationString) {
          stringValue += element.value;
        }
      }

      // no text besides interpolated strings; ignore
      if (stringValue.isEmpty) return;

      // ignore string interpolation with text only one character long
      if (stringValue.length == 1) return;

      // ignore if it looks like a URI or path
      if (_looksLikeUriOrPath(stringValue)) return;

      if (_checkIfIgnoreToDueMethod(node)) return;

      reporter.reportErrorForNode(code, node);
    });
  }

  bool _checkIfIgnoreToDueMethod(StringLiteral node) {
    final methodInvocation = node.thisOrAncestorOfType<MethodInvocation>();
    if (methodInvocation == null) return false;
    final method = methodInvocation.methodName.name;

    final ignore = <String>{
      'message',
      'log',
      'error',
      'pushNamed',
      'captureMessage'
    };
    if (ignore.contains(method)) return true;

    return false;
  }
}
