import { Header } from "../modules/header";
import Routing from "../pages";
import RootStore from "../stores/root-store";
import { RootStoreContext } from "./root-store-context";

const App = () => {
  return (
    <RootStoreContext.Provider value={new RootStore()}>
      <Header />
      <Routing />
    </RootStoreContext.Provider>
  );
};

export default App;
