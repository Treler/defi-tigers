import * as stylex from "@stylexjs/stylex";
import { ChangeEvent, useRef } from "react";

const styles = stylex.create({
  input: (error: boolean) => ({
    padding: "0 0 0 10px",
    height: "40px",
    width: "100%",
    background: "transparent",
    fontFamily: `"Roboto","Helvetica","Arial",sans-serif`,
    fontWeight: "500",
    fontSize: "1rem",
    lineHeight: "1.2",
    letterSpacing: "0.0075em",
    color: "#f8f8f8",
    border: {
      default: !error ? "1px solid #f8f8f8" : "1px solid #1976d2",
      ":focus": "2px solid #f8f8f8",
    },
  }),
  error: {
    margin: "10px 0",
    fontFamily: `"Roboto","Helvetica","Arial",sans-serif`,
    fontWeight: "500",
    fontSize: "1rem",
    lineHeight: "1.2",
    letterSpacing: "0.0075em",
    color: "#1976d2",
  },
  text: {
    margin: "0 20px 0 10px",
    fontFamily: `"Roboto","Helvetica","Arial",sans-serif`,
    fontWeight: "500",
    fontSize: "1rem",
    lineHeight: "1.2",
    letterSpacing: "0.0075em",
    color: "#f8f8f8",
  },
});

interface Props {
  name: string;
  type: "text";
  placeholder: string;
  value: string;
  onChange: (e: ChangeEvent<HTMLInputElement>) => void;
  disabled?: boolean;
  error?: string;
}

const Input = (props: Props) => {
  const {
    name,
    type,
    placeholder,
    value,
    onChange,
    disabled,
    error,
  } = props;

  const inputRef = useRef<HTMLInputElement>(null);

  const handleClick = () => {
    if (inputRef && inputRef.current) inputRef.current.focus();
  };

  return (
    <div>
      <input
        {...stylex.props(styles.input(error !== undefined))}
        onClick={handleClick}
        ref={inputRef}
        aria-label={name}
        data-testid={name}
        tabIndex={0}
        type={type}
        name={name}
        onChange={onChange}
        placeholder={placeholder}
        value={value}
        disabled={disabled}
      />

      {error !== undefined && <p {...stylex.props(styles.error)}>{error}</p>}
    </div>
  );
};

export default Input;
