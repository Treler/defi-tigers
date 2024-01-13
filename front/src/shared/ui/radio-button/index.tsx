import * as stylex from "@stylexjs/stylex";

const styles = stylex.create({
  radioLabel: {
    display: "flex",
    alignItems: "center",
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
  radioInput: {
    margin: "0",
    display: "none",
  },
  customRadio: (checked: boolean) => ({
    cursor: "pointer",
    width: "20px",
    height: "20px",
    border: `2px solid #f8f8f8`,
    borderRadius: "50%",
    display: "inline-block",
    position: "relative",
    "::after": {
      content: "",
      width: "12px",
      height: "12px",
      background: "#f8f8f8",
      position: "absolute",
      borderRadius: "50%",
      top: "50%",
      left: "50%",
      transform: `translate(-50%, -50%)`,
      opacity: checked ? "1" : "0",
      transition: `opacity 0.2s`,
    },
  }),
});

interface Props {
  name: string;
  id: string;
  value: string;
  onChange: () => void;
  checked: boolean;
  text: string;
}

const RadioButton = (props: Props) => {
  const { name, id, value, onChange, checked, text } = props;
  return (
    <label htmlFor={id} {...stylex.props(styles.radioLabel)}>
      <input
        {...stylex.props(styles.radioInput)}
        type="radio"
        name={name}
        id={id}
        value={value}
        onChange={onChange}
        checked={checked}
      />
      <span {...stylex.props(styles.customRadio(checked))} />
      <span {...stylex.props(styles.text)}>{text}</span>
    </label>
  );
};

export default RadioButton;
