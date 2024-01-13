import { lazy } from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";

const Main = lazy(() => import("./main"));

const Routing = () => {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/defi-tigers-frontend" element={<Main />} />
      </Routes>
    </BrowserRouter>
  );
};

export default Routing;
