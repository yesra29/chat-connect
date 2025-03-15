final RegExp EMAIL_VALIDATOR_REGEX= RegExp( r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
final RegExp PASSWORD_VALIDATOR_REGEX= RegExp(  r"^(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$");
final RegExp NAME_VALIDATOR_REGEX= RegExp( r"\b([A-ZA`-y``][-,a-z.");