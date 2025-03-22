final RegExp EMAIL_VALIDATOR_REGEX= RegExp( r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
final RegExp PASSWORD_VALIDATOR_REGEX= RegExp(  r"^(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$");
final RegExp NAME_VALIDATION_REGEX= RegExp(r"^[a-zA-Z]+(?: [a-zA-Z]+)*$");
const String PLACEHOLDER_PFP = "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y";